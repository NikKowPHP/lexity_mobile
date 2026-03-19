import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../models/book.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/logger_service.dart';
import '../../theme/liquid_theme.dart';

import 'book_reader_html.dart';
import 'book_reader/reader_file_service.dart';
import 'book_reader/reader_bridge_controller.dart';
import 'book_reader/widgets/reader_settings_sheet.dart';
import 'book_reader/widgets/reader_toc_sheet.dart';
import 'book_reader/widgets/translation_bottom_sheet.dart';
import 'book_reader/widgets/vocabulary_review_sheet.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  final double initialProgress;
  const BookReaderScreen({
    super.key,
    required this.bookId,
    this.initialProgress = 0.0,
  });

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen>
    with WidgetsBindingObserver {
  late final ReaderFileService _fileService;
  late final ReaderBridgeController _bridgeController;

  Completer<void>? _portReadyCompleter;
  double _progress = 0.0;
  String? _lastCfi;
  String? _currentCfi;
  bool _isDownloading = false;
  bool _localFileReady = false;
  String _theme = 'light';
  double _fontSize = 100.0;
  List<dynamic> _toc = [];
  double _downloadProgress = 0.0;
  Timer? _progressDebounce;

  int? _localPort;

  bool _isInitialized = false;
  String? _lastSavedCfi;
  bool _hasLocationsFromBackend = false;
  bool _readerReady = false;
  bool _vocabPrefetched = false;
  String? _appliedTheme;
  double? _appliedFontSize;

  // Flag to prevent early '0%' percentage reports from overwriting DB progress
  bool _canSaveToBackend = false;

  // Track initial CFI when book opens to only save on user navigation
  String? _initialCfiOnReady;

  Map<String, String> _themeColors() {
    return {
      'light': {'bg': '#ffffff', 'fg': '#000000'},
      'dark': {'bg': '#121212', 'fg': '#e4e4e4'},
      'sepia': {'bg': '#f4ecd8', 'fg': '#5b4636'},
    }[_theme]!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fileService = ReaderFileService(ref);
    _bridgeController = ReaderBridgeController(ref);
    _setupBridgeCallbacks();
    if (!kIsWeb) {
      _startLocalServer();
    } else {
      _localPort = 0;
    }
  }

  void _setupBridgeCallbacks() {
    _bridgeController.onProgress = _handleProgress;
    _bridgeController.onToc = _handleToc;
    _bridgeController.onReady = _handleReaderReady;
    _bridgeController.onWordTap = _handleWordTap;
    _bridgeController.onTextSelected = _handleTextSelected;
    _bridgeController.onParagraphTranslate = _handleParagraphTranslate;
    _bridgeController.onLocationsGenerated = _handleLocationsGenerated;
  }

  Future<void> _startLocalServer() async {
    final logger = ref.read(loggerProvider);
    if (kIsWeb) {
      logger.info('BookReader: Web detected, skipping local server.');
      return;
    }
    logger.info('BookReader: Initializing local file server');
    try {
      _localPort = await _fileService.start();
      if (mounted) {
        logger.info('BookReader: Local server bound to port $_localPort');
      }
    } catch (e, st) {
      logger.error('BookReader: Local server startup error', e, st);
    }
  }

  Future<void> _ensureBookDownloaded(UserBook book) async {
    final logger = ref.read(loggerProvider);
    if (_isDownloading || _localFileReady) return;

    if (kIsWeb) {
      setState(() => _localFileReady = true);
      return;
    }

    try {
      await _fileService.ensureBookDownloaded(
        bookId: book.id,
        signedUrl: book.signedUrl,
        bookTitle: book.title,
        isDownloading: _isDownloading,
        localFileReady: _localFileReady,
        setIsDownloading: (v) => setState(() => _isDownloading = v),
        setDownloadProgress: (v) => setState(() => _downloadProgress = v),
        setLocalFileReady: (v) => setState(() => _localFileReady = v),
      );
    } catch (e, st) {
      logger.error('BookReader: Download setup failed', e, st);
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _handleProgress(String cfi, double pct) {
    if (!mounted) return;
    final logger = ref.read(loggerProvider);

    if (pct == 0 && widget.initialProgress > 0 && !_canSaveToBackend) {
      return;
    }

    final acceptProgress =
        _hasLocationsFromBackend ||
        (pct >= 0 && pct < 100) ||
        (_progress >= 95 && pct >= 100);

    logger.info(
      'BookReader: onProgress received - CFI: $cfi, Progress: $pct%, acceptProgress: $acceptProgress, hasLocations: $_hasLocationsFromBackend, canSave: $_canSaveToBackend, initialCfiOnReady: $_initialCfiOnReady, lastSavedCfi: $_lastSavedCfi',
    );

    // Detect Page Flip (CFI changed)
    if (_currentCfi != null && _currentCfi != cfi) {
      logger.info(
        'BookReader: Page flip detected from $_currentCfi to $cfi, requesting visible words',
      );
      _bridgeController.getVisibleUnknownWords().then((wordsObj) {
        if (wordsObj.isNotEmpty) {
          _triggerVocabReview(wordsObj);
        }
      });
    }

    if (mounted) {
      setState(() {
        _lastCfi = cfi;
        _currentCfi = cfi;
        if (acceptProgress) {
          _progress = pct;
        }
      });
    }

    // Ensure we don't push progress to the backend during initial setup
    if (!_canSaveToBackend) return;

    // Only save if user has moved to a different position from initial
    if (_initialCfiOnReady != null && cfi == _initialCfiOnReady) {
      logger.info('BookReader: Skipping save - at initial position: $cfi');
      return;
    }

    if (mounted && _lastCfi != _lastSavedCfi) {
      final progressToSave = acceptProgress ? _progress : _progress;
      logger.info(
        'BookReader: Saving progress - CFI: $_lastCfi, Progress: $progressToSave% (acceptProgress: $acceptProgress)',
      );
      _progressDebounce?.cancel();
      _progressDebounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        ref
            .read(bookNotifierProvider.notifier)
            .updateProgress(widget.bookId, _lastCfi!, progressToSave);
        _lastSavedCfi = _lastCfi;
      });
    }

    _updateReaderStyles();
  }

  void _handleToc(List<dynamic> toc) {
    if (mounted) setState(() => _toc = toc);
  }

  void _handleReaderReady() async {
    final logger = ref.read(loggerProvider);
    final book = ref.read(bookDetailProvider(widget.bookId)).value;
    if (book == null) return;

    logger.info(
      'BookReader: onReady fired, enabling save and sending vocabulary/locations',
    );
    if (mounted) {
      setState(() {
        _canSaveToBackend = true;
        _readerReady = true;
      });
    }

    _updateReaderStyles(force: true);

    if (!mounted) return;

    await _portReadyCompleter?.future;

    _bridgeController.signalPortReady();

    if (book.locations != null && book.locations!.length > 5) {
      _bridgeController.sendLocations(book.locations!);
    }

    final vocabData = await ref
        .read(vocabularyProvider.notifier)
        .getVocabulary(book.targetLanguage);
    if (mounted &&
        _bridgeController.vocabPort != null &&
        vocabData.isNotEmpty) {
      _bridgeController.sendVocabDelta(vocabData);
    }
  }

  void _handleWordTap(String word, String contextText) {
    // 1. Handle vocabulary update for unknown words
    final currentStatus = ref
        .read(vocabularyProvider)
        .value?[word.toLowerCase()];
    if (currentStatus == null || currentStatus.toLowerCase() == 'unknown') {
      final book = ref.read(bookDetailProvider(widget.bookId)).value;
      if (book != null) {
        ref
            .read(vocabularyProvider.notifier)
            .updateWordStatus(word, 'known', book.targetLanguage);
      }
    }

    // 2. Open the translation sheet
    final book = ref.read(bookDetailProvider(widget.bookId)).value;
    final profile = ref.read(userProfileProvider).value;

    if (book != null && profile != null) {
      _showTranslationSheet(
        context,
        selectedText: word,
        contextText: contextText,
        sourceLang: book.targetLanguage,
        nativeLang: profile.nativeLanguage ?? 'english',
      );
    }
  }

  void _handleTextSelected(String selectedText, String contextText) {
    final book = ref.read(bookDetailProvider(widget.bookId)).value;
    final profile = ref.read(userProfileProvider).value;
    if (book != null && profile != null) {
      _showTranslationSheet(
        context,
        selectedText: selectedText,
        contextText: contextText,
        sourceLang: book.targetLanguage,
        nativeLang: profile.nativeLanguage ?? 'english',
      );
    }
  }

  void _handleParagraphTranslate(String text) {
    final book = ref.read(bookDetailProvider(widget.bookId)).value;
    final profile = ref.read(userProfileProvider).value;
    if (book != null && profile != null) {
      _showTranslationSheet(
        context,
        selectedText: text,
        contextText: text,
        sourceLang: book.targetLanguage,
        nativeLang: profile.nativeLanguage ?? 'english',
      );
    }
  }

  void _handleLocationsGenerated(String locationsJson) {
    ref
        .read(bookNotifierProvider.notifier)
        .updateLocations(widget.bookId, locationsJson);
  }

  void _updateReaderStyles({bool force = false}) {
    final logger = ref.read(loggerProvider);
    if (!force && _appliedTheme == _theme && _appliedFontSize == _fontSize) {
      return;
    }
    _appliedTheme = _theme;
    _appliedFontSize = _fontSize;
    logger.debug(
      'BookReader: Updating styles (Theme: $_theme, Size: $_fontSize%, lastCfi: $_lastCfi, currentCfi: $_currentCfi, lastSavedCfi: $_lastSavedCfi, initialCfiOnReady: $_initialCfiOnReady)',
    );

    final colors = _themeColors();
    _bridgeController.updateTheme(colors, _fontSize, _theme);
  }

  void _handleImmediateSave() {
    if (!mounted || _lastCfi == null) return;
    if (!_canSaveToBackend) return;
    if (_lastCfi == _lastSavedCfi) return;

    final logger = ref.read(loggerProvider);
    logger.info(
      'BookReader: Performing immediate progress save on exit/background. CFI: $_lastCfi',
    );
    ref
        .read(bookNotifierProvider.notifier)
        .updateProgress(widget.bookId, _lastCfi!, _progress);
    _lastSavedCfi = _lastCfi;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressDebounce?.cancel();
    _handleImmediateSave();
    _bridgeController.shutdown();
    _bridgeController.closePort();
    _fileService.stop();
    _bridgeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _handleImmediateSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.bookId));
    final logger = ref.read(loggerProvider);

    bookAsync.whenData((book) {
      if (!_isInitialized) {
        logger.info(
          'BookReader: Initializing state. Saved CFI: ${book.currentCfi}',
        );
        _isInitialized = true;
        setState(() {
          _progress = book.progressPct;
          _lastCfi = book.currentCfi;
          _lastSavedCfi = book.currentCfi;
          _initialCfiOnReady = book.currentCfi;
          _hasLocationsFromBackend = book.locations != null;
        });
        _ensureBookDownloaded(book);
        if (!_vocabPrefetched) {
          _vocabPrefetched = true;
          ref
              .read(vocabularyProvider.notifier)
              .loadVocabulary(book.targetLanguage);
        }
      } else if (!_hasLocationsFromBackend && book.locations != null) {
        setState(() => _hasLocationsFromBackend = true);
      }
    });

    ref.listen(paginatedVocabularyProvider, (previous, next) {
      if (next.delta != null && _bridgeController.vocabPort != null) {
        _bridgeController.sendVocabDelta(next.delta!);
        ref.read(paginatedVocabularyProvider.notifier).clearDelta();
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && mounted) {
          _handleImmediateSave();
        }
      },
      child: Scaffold(
        backgroundColor: _theme == 'dark'
            ? const Color(0xFF121212)
            : (_theme == 'sepia' ? const Color(0xFFf4ecd8) : Colors.white),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(
            color: _theme == 'light' ? Colors.black87 : Colors.white,
          ),
          title: Text(
            "${_progress.round()}% Read",
            style: TextStyle(
              fontSize: 14,
              color: _theme == 'light' ? Colors.black87 : Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/library');
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
              ),
              onPressed: () async {
                final book = bookAsync.value;
                if (book == null) return;
                final words = await _bridgeController.getVisibleUnknownWords();
                if (words.isNotEmpty) {
                  ref
                      .read(vocabularyProvider.notifier)
                      .markBatchKnown(words, book.targetLanguage);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Marked ${words.length} words as known"),
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No unknown words on this page."),
                      ),
                    );
                  }
                }
              },
            ),
            if (_toc.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.list),
                onPressed: () => _showChapterBrowser(context),
              ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettings(context),
            ),
          ],
        ),
        body: SizedBox.expand(
          child: Stack(
            children: [
              bookAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) {
                  logger.error('BookReader: Failed to load data', e, st);
                  return Center(child: Text("Error: $e"));
                },
                data: (book) {
                  if (_isDownloading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            color: LiquidTheme.primaryAccent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!_localFileReady || _localPort == null) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: LiquidTheme.primaryAccent,
                      ),
                    );
                  }

                  return InAppWebView(
                    initialData: kIsWeb
                        ? InAppWebViewInitialData(
                            data: bookReaderHtmlTemplate,
                            baseUrl: WebUri("/"),
                          )
                        : null,
                    initialUrlRequest: !kIsWeb
                        ? URLRequest(
                            url: WebUri("http://localhost:$_localPort/"),
                          )
                        : null,
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      databaseEnabled: true,
                      isInspectable: kDebugMode,
                      allowUniversalAccessFromFileURLs: true,
                      allowFileAccessFromFileURLs: true,
                      mixedContentMode:
                          MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                      transparentBackground: true,
                      safeBrowsingEnabled: false,
                      allowContentAccess: true,
                      allowFileAccess: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                    ),
                    onWebViewCreated: (controller) async {
                      await _bridgeController.initialize(
                        controller: controller,
                      );
                      logger.info('BookReader: WebView created');

                      _portReadyCompleter = Completer<void>();
                    },
                    onLoadStop: (controller, _) async {
                      if (kIsWeb || _localPort != null) {
                        if (mounted) {
                          setState(() => _readerReady = false);
                        }
                        final String bookUrl = kIsWeb
                            ? (book.signedUrl ?? '')
                            : "http://localhost:$_localPort/books/${book.id}.epub";

                        final colors = _themeColors();

                        logger.info(
                          'BookReader: Calling loadBook with CFI: ${_lastCfi ?? ""}',
                        );
                        _bridgeController.loadBook(
                          bookUrl: bookUrl,
                          initialCfi: _lastCfi ?? '',
                          colors: colors,
                          themeName: _theme,
                          fontSize: _fontSize,
                        );
                      }
                    },
                  );
                },
              ),
              if (!_readerReady)
                Positioned.fill(
                  child: Container(
                    color: _theme == 'dark'
                        ? const Color(0xFF121212)
                        : (_theme == 'sepia'
                              ? const Color(0xFFf4ecd8)
                              : Colors.white),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: LiquidTheme.primaryAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChapterBrowser(BuildContext context) {
    ReaderTocSheet.show(
      context: context,
      toc: _toc,
      onChapterSelected: (href) {
        _bridgeController.displayHref(href);
      },
    );
  }

  void _showSettings(BuildContext context) {
    ReaderSettingsSheet.show(
      context: context,
      currentTheme: _theme,
      currentFontSize: _fontSize,
      onSettingsChanged: (theme, fontSize) {
        setState(() {
          _theme = theme;
          _fontSize = fontSize;
        });
        _updateReaderStyles();
      },
    );
  }

  Future<void> _showTranslationSheet(
    BuildContext context, {
    required String selectedText,
    required String contextText,
    required String sourceLang,
    required String nativeLang,
  }) async {
    await TranslationBottomSheet.show(
      context: context,
      selectedText: selectedText,
      contextText: contextText,
      sourceLang: sourceLang,
      targetLang: nativeLang,
    );

    _bridgeController.clearSelection();
  }

  void _triggerVocabReview(List<String> words) {
    if (!mounted || words.isEmpty) return;

    final book = ref.read(bookDetailProvider(widget.bookId)).value;
    if (book == null) return;

    VocabularyReviewSheet.show(
      context: context,
      words: words,
      targetLanguage: book.targetLanguage,
      webViewController: _bridgeController.controller,
    );
  }
}
