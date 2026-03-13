import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:lexity_mobile/providers/srs_provider.dart';
import '../../models/book.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/logger_service.dart';
import '../../theme/liquid_theme.dart';
import '../../services/ai_service.dart';
import '../widgets/liquid_components.dart';

import 'book_reader_html.dart';

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

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  InAppWebViewController? webViewController;
  // FIX: Initialize immediately to prevent LateInitializationError
  double _progress = 0.0;
  String? _lastCfi;
  String? _currentCfi; // Track for page flips
  bool _isDownloading = false;
  bool _localFileReady = false;
  String _theme = 'light';
  double _fontSize = 100.0;
  List<dynamic> _toc = [];
  double _downloadProgress = 0.0;

  Timer? _progressDebounce;
  HttpServer? _localServer;
  int? _localPort;

  bool _isInitialized = false;

  // Flag to prevent early '0%' percentage reports from overwriting DB progress
  bool _canSaveToBackend = false;

  void _updateReaderStyles() {
    final logger = ref.read(loggerProvider);
    logger.debug(
      'BookReader: Updating styles (Theme: $_theme, Size: $_fontSize%)',
    );

    final colors = {
      'light': {'bg': '#ffffff', 'fg': '#000000'},
      'dark': {'bg': '#121212', 'fg': '#e4e4e4'},
      'sepia': {'bg': '#f4ecd8', 'fg': '#5b4636'},
    }[_theme]!;

    webViewController?.evaluateJavascript(
      source: "if (window.applyTheme) window.applyTheme(${jsonEncode(colors)}, $_fontSize, '$_theme');",
    );
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _startLocalServer();
    } else {
      // On Web, we don't use a local server. Set a dummy port to pass the initialization check.
      _localPort = 0;
    }
  }

  Future<void> _startLocalServer() async {
    final logger = ref.read(loggerProvider);
    if (kIsWeb) {
      logger.info('BookReader: Web detected, skipping local server.');
      return;
    }
    logger.info('BookReader: Initializing local file server');
    try {
      _localServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (mounted) {
        setState(() => _localPort = _localServer!.port);
        logger.info('BookReader: Local server bound to port $_localPort');
      }

      _localServer!.listen((HttpRequest request) async {
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add(
          'Access-Control-Allow-Methods',
          'GET, OPTIONS',
        );
        request.response.headers.add('Access-Control-Allow-Headers', '*');

        if (request.method == 'OPTIONS') {
          request.response.statusCode = 200;
          await request.response.close();
          return;
        }

        // NEW CODE START: Serve the reader HTML at the root to avoid initialData bugs on Linux
        if (request.uri.path == '/') {
          request.response.headers.contentType = ContentType.html;
          request.response.write(bookReaderHtmlTemplate);
          await request.response.close();
          return;
        }
        // NEW CODE END
        if (request.uri.path.startsWith('/books/')) {
          final bookId = request.uri.pathSegments.last.replaceAll('.epub', '');
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/books/$bookId.epub');

          if (await file.exists()) {
            logger.debug('BookReader: Serving local EPUB file for $bookId');
            final length = await file.length();
            request.response.contentLength = length;
            request.response.headers.contentType = ContentType(
              'application',
              'epub+zip',
              charset: 'utf-8',
            );
            await request.response.addStream(file.openRead());
            await request.response.close();
            return;
          }
        }
        request.response.statusCode = 404;
        await request.response.close();
      });
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
      final dir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${dir.path}/books');
      if (!await booksDir.exists()) await booksDir.create(recursive: true);

      final file = File('${booksDir.path}/${book.id}.epub');
      if (await file.exists()) {
        logger.info('BookReader: Book "${book.title}" found locally');
        if (mounted) setState(() => _localFileReady = true);
        return;
      }

      logger.info(
        'BookReader: Book not found locally, starting download for "${book.title}"',
      );
      if (book.signedUrl == null) {
        logger.error('BookReader: Missing signedUrl for book ${book.id}');
        throw Exception("No download URL provided");
      }

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final request = http.Request('GET', Uri.parse(book.signedUrl!));
      final response = await request.send();
      final total = response.contentLength ?? 0;
      int received = 0;
      final bytes = <int>[];

      response.stream.listen(
        (chunk) {
          bytes.addAll(chunk);
          received += chunk.length;
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
        onDone: () async {
          await file.writeAsBytes(bytes);
          logger.info('BookReader: Download complete for "${book.title}"');
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _localFileReady = true;
            });
          }
        },
        onError: (e, st) {
          logger.error('BookReader: Download stream error', e, st);
          if (mounted) setState(() => _isDownloading = false);
        },
      );
    } catch (e, st) {
      logger.error('BookReader: Download setup failed', e, st);
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _handleImmediateSave() {
    if (!mounted || _lastCfi == null) return;
    // Prevent saving if the book hasn't fully settled on the correct page yet
    if (!_canSaveToBackend) return;

    final logger = ref.read(loggerProvider);
    _progressDebounce?.cancel();
    logger.info(
      'BookReader: Performing immediate progress save on screen exit. CFI: $_lastCfi',
    );
    ref
        .read(bookNotifierProvider.notifier)
        .updateProgress(widget.bookId, _lastCfi!, _progress);
    _lastCfi = null; // Prevent double saving
  }

  @override
  void dispose() {
    _handleImmediateSave(); // Catch-all guarantee
    _progressDebounce?.cancel();
    _localServer?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.bookId));
    final profileAsync = ref.watch(userProfileProvider);
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
        });
        _ensureBookDownloaded(book);
      }
    });

    ref.listen(vocabularyProvider, (previous, next) {
      next.whenData((vocabMap) {
        if (webViewController != null) {
          final jsonStr = jsonEncode(vocabMap);
          final jsString = jsonEncode(jsonStr);
          webViewController?.evaluateJavascript(
            source:
                "if (window.applyVocabStyles) window.applyVocabStyles($jsString);",
          );
        }
      });
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
                context.go('/library'); // Fallback for deep-linked reader
              }
            },
          ),
          actions: [
            // NEW: MARK PAGE KNOWN BUTTON
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
              ),
              onPressed: () async {
                final book = bookAsync.value;
                if (book == null) return;
                final wordsObj = await webViewController?.evaluateJavascript(
                  source: "window.getVisibleUnknownWords();",
                );
                if (wordsObj != null && wordsObj is List) {
                  final words = wordsObj.map((e) => e.toString()).toList();
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
                    // FIX: On Web, use initialData. On Mobile, use the Proxy Server.
                    initialData: kIsWeb
                        ? InAppWebViewInitialData(
                            data: bookReaderHtmlTemplate,
                            baseUrl: WebUri("/"), // Grants a proper origin context vs "null"
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
                      // NEW CODE: Fix potential compositor issues on Linux/GTK
                      transparentBackground: true,
                      safeBrowsingEnabled: false,
                      allowContentAccess: true,
                      allowFileAccess: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                    ),
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                      controller.addJavaScriptHandler(
                        handlerName: 'onProgress',
                        callback: (args) {
                          if (!mounted) return;

                          final cfi = args[0] as String;
                          final pct = (args[1] as num).toDouble();

                          // Detect Page Flip (CFI changed)
                          if (_currentCfi != null && _currentCfi != cfi) {
                            // Get words that WERE visible on the page we just left
                            webViewController
                                ?.evaluateJavascript(
                                  source: "window.getVisibleUnknownWords();",
                                )
                                .then((wordsObj) {
                              if (wordsObj != null && wordsObj is List) {
                                final words =
                                    wordsObj.map((e) => e.toString()).toList();
                                if (words.isNotEmpty) _triggerVocabReview(words);
                              }
                            });
                          }

                          if (mounted) {
                            setState(() {
                              // Always track the current location so we don't lose our place
                              _lastCfi = cfi;
                              _currentCfi = cfi;

                              // Only update visual percentage after initial load settles to prevent jitter
                              if (_canSaveToBackend) {
                                _progress = pct;
                              }
                            });
                          }

                          // Ensure we don't push progress to the backend during initial setup
                          if (!_canSaveToBackend) return;

                          _progressDebounce?.cancel();
                          _progressDebounce = Timer(
                            const Duration(milliseconds: 1500),
                            () {
                              if (mounted) {
                                ref
                                    .read(bookNotifierProvider.notifier)
                                    .updateProgress(book.id, cfi, pct);
                              }
                            },
                          );

                          _updateReaderStyles();
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'onToc',
                        callback: (args) {
                          final tocData = args[0] as List<dynamic>;
                          if (mounted) setState(() => _toc = tocData);
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'onParagraphTranslate',
                        callback: (args) {
                          final text = args[0].toString();
                          _showTranslationSheet(
                            context,
                            selectedText: text,
                            contextText: text,
                            sourceLang: book.targetLanguage,
                            nativeLang:
                                profileAsync.value?.nativeLanguage ?? 'english',
                          );
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'onReady',
                        callback: (_) {
                          // 1. Trigger the load from backend
                          ref
                              .read(vocabularyProvider.notifier)
                              .loadVocabulary(book.targetLanguage);

                          Future.delayed(const Duration(milliseconds: 1500), () {
                            if (mounted) setState(() => _canSaveToBackend = true);
                          });

                          _updateReaderStyles();
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'onWordTap',
                        callback: (args) {
                          final word = args[0] as String;
                          final contextText = args[3] as String;

                          // 1. Handle vocabulary update for unknown words
                          final currentStatus = ref
                              .read(vocabularyProvider)
                              .value?[word.toLowerCase()];
                          if (currentStatus == null ||
                              currentStatus.toLowerCase() == 'unknown') {
                            final book = ref
                                .read(bookDetailProvider(widget.bookId))
                                .value;
                            if (book != null) {
                              ref
                                  .read(vocabularyProvider.notifier)
                                  .updateWordStatus(
                                    word,
                                    'known',
                                    book.targetLanguage,
                                  );
                            }
                          }

                          // 2. Open the existing bottom sheet instead of a tooltip
                          final book = ref
                              .read(bookDetailProvider(widget.bookId))
                              .value;
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
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'onBackgroundTap',
                        callback: (_) {
                          // No action needed for background tap
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'onChapterReady',
                        callback: (_) {
                          // Ensure current vocab is sent to every new chapter as it loads
                          final vocabData = ref.read(vocabularyProvider).value;
                          if (vocabData != null) {
                            final jsonStr = jsonEncode(vocabData);
                            final jsString = jsonEncode(jsonStr);
                            webViewController?.evaluateJavascript(
                              source:
                                  "if (window.applyVocabStyles) window.applyVocabStyles($jsString);",
                            );
                          }
                        },
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'onTextSelected',
                        callback: (args) {
                          _showTranslationSheet(
                            context,
                            selectedText: args[0].toString(),
                            contextText: args[1].toString(),
                            sourceLang: book.targetLanguage,
                            nativeLang:
                                profileAsync.value?.nativeLanguage ?? 'english',
                          );
                        },
                      );
                    },
                    onLoadStop: (controller, _) async {
                      if (kIsWeb || _localPort != null) {
                        final String bookUrl = kIsWeb
                            ? (book.signedUrl ?? '')
                            : "http://localhost:$_localPort/books/${book.id}.epub";
                        final jsCall =
                            "loadBook(${jsonEncode(bookUrl)}, ${jsonEncode(_lastCfi ?? '')});";
                        await controller.evaluateJavascript(source: jsCall);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChapterBrowser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Table of Contents",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: _toc.length,
                separatorBuilder: (context, index) =>
                    const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final chapter = _toc[index];
                  final int level = chapter['level'] ?? 0;

                  return ListTile(
                    contentPadding: EdgeInsets.only(
                      left: 16.0 + (level * 16.0),
                      right: 16.0,
                    ),
                    title: Text(
                      chapter['label'].toString().trim(),
                      style: TextStyle(
                        color: level == 0 ? Colors.white : Colors.white70,
                        fontWeight: level == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: level == 0 ? 15 : 14,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                      size: 16,
                    ),
                    onTap: () {
                      final href = chapter['href'].toString();
                      webViewController?.evaluateJavascript(
                        source: "rendition.display('$href');",
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Appearance",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['light', 'dark', 'sepia']
                    .map(
                      (t) => GestureDetector(
                        onTap: () {
                          setState(() => _theme = t);
                          setModalState(() {});
                          _updateReaderStyles();
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: t == 'light'
                                ? Colors.white
                                : (t == 'sepia'
                                      ? const Color(0xFFf4ecd8)
                                      : const Color(0xFF333333)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _theme == t
                                  ? LiquidTheme.primaryAccent
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 16),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 80,
                      max: 200,
                      onChanged: (v) {
                        setState(() => _fontSize = v);
                        setModalState(() {});
                      },
                      onChangeEnd: (v) {
                        _updateReaderStyles();
                      },
                    ),
                  ),
                  const Icon(Icons.text_fields, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTranslationSheet(
    BuildContext context, {
    required String selectedText,
    required String contextText,
    required String sourceLang,
    required String nativeLang,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TranslationBottomSheet(
        selectedText: selectedText,
        contextText: contextText,
        sourceLang: sourceLang,
        targetLang: nativeLang,
      ),
    );

    webViewController?.evaluateJavascript(
      source: """
      if (typeof rendition !== 'undefined' && rendition) {
        rendition.getContents().forEach(c => c.window.getSelection().removeAllRanges());
        window.lastReportedText = "";
      }
    """,
    );
  }

  void _triggerVocabReview(List<String> words) {
    if (!mounted || words.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _VocabularyReviewSheet(
        words: words,
        targetLanguage: ref.read(activeLanguageProvider),
      ),
    );
  }
}

class _TranslationBottomSheet extends ConsumerStatefulWidget {
  final String selectedText;
  final String contextText;
  final String sourceLang;
  final String targetLang;

  const _TranslationBottomSheet({
    required this.selectedText,
    required this.contextText,
    required this.sourceLang,
    required this.targetLang,
  });

  @override
  ConsumerState<_TranslationBottomSheet> createState() =>
      _TranslationBottomSheetState();
}

class _TranslationBottomSheetState
    extends ConsumerState<_TranslationBottomSheet> {
  bool _isLoadingFast = true;
  bool _isLoadingContext = false;
  String? _fastTranslation;
  String? _contextualTranslation;
  String? _explanation;
  bool _isAdding = false;
  bool _isAdded = false;

  @override
  void initState() {
    super.initState();
    _fetchFastTranslation();
  }

  Future<void> _fetchFastTranslation() async {
    final logger = ref.read(loggerProvider);
    try {
      final aiService = ref.read(aiServiceProvider);
      final result = await aiService.translate(
        widget.selectedText,
        widget.sourceLang,
        widget.targetLang,
      );
      if (mounted) {
        setState(() {
          _fastTranslation = result;
          _isLoadingFast = false;
        });
      }
    } catch (e, st) {
      logger.error('BookReader: Fast translation failed', e, st);
      if (mounted) {
        setState(() {
          _fastTranslation = "Failed to translate";
          _isLoadingFast = false;
        });
      }
    }
  }

  Future<void> _fetchContextTranslation() async {
    final logger = ref.read(loggerProvider);
    logger.info('BookReader: Requesting context-aware translation');
    setState(() => _isLoadingContext = true);
    try {
      final aiService = ref.read(aiServiceProvider);
      final result = await aiService.contextualTranslate(
        selectedText: widget.selectedText,
        context: widget.contextText,
        sourceLanguage: widget.sourceLang,
        targetLanguage: widget.targetLang,
        nativeLanguage: widget.targetLang,
      );
      if (mounted) {
        setState(() {
          _contextualTranslation = result['translation'];
          _explanation = result['explanation'];
          _isLoadingContext = false;
        });
      }
    } catch (e, st) {
      logger.error('BookReader: Context translation failed', e, st);
      if (mounted) {
        setState(() {
          _isLoadingContext = false;
        });
      }
    }
  }

  Future<void> _handleAddToDeck() async {
    setState(() => _isAdding = true);
    final success = await ref
        .read(srsProvider.notifier)
        .addToDeckFromTranslation(
          front: widget.selectedText,
          back: _contextualTranslation ?? _fastTranslation!,
          language: widget.sourceLang,
          explanation: _explanation,
        );

    if (mounted) {
      setState(() {
        _isAdding = false;
        if (success) {
          _isAdded = true;
          // NEW: Trigger local vocab update so the word color changes in the background
          ref.read(vocabularyProvider.notifier).updateWordStatus(
                widget.selectedText,
                'learning',
                widget.sourceLang,
              );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.selectedText,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoadingFast)
            const CircularProgressIndicator()
          else
            Text(
              _fastTranslation ?? "",
              style: const TextStyle(
                fontSize: 18,
                color: LiquidTheme.primaryAccent,
                fontWeight: FontWeight.w600,
              ),
            ),

          const SizedBox(height: 24),

          if (_contextualTranslation == null && !_isLoadingContext)
            OutlinedButton.icon(
              onPressed: _fetchContextTranslation,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text(
                "Deep Translate with Context",
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
              ),
            )
          else if (_isLoadingContext)
            const Center(
              child: CircularProgressIndicator(
                color: LiquidTheme.secondaryAccent,
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _contextualTranslation!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _explanation ?? "",
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdded
                    ? Colors.green.withValues(alpha: 0.2)
                    : LiquidTheme.primaryAccent,
                foregroundColor: _isAdded ? Colors.greenAccent : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: (_isLoadingFast || _isAdded || _isAdding)
                  ? null
                  : _handleAddToDeck,
              icon: _isAdding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isAdded ? Icons.check : Icons.add),
              label: Text(
                _isAdded ? "Added to Deck" : "Add to Study Deck",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _VocabularyReviewSheet extends ConsumerWidget {
  final List<String> words;
  final String targetLanguage;

  const _VocabularyReviewSheet({
    required this.words,
    required this.targetLanguage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${words.length} New Words",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "How do you want to handle these words?",
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: ListView.builder(
              itemCount: words.length,
              itemBuilder: (context, i) => ListTile(
                title:
                    Text(words[i], style: const TextStyle(color: Colors.white)),
                trailing: const Icon(
                  Icons.help_outline,
                  color: Colors.white24,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: LiquidButton(
                  text: "Mark All Known",
                  onTap: () {
                    ref
                        .read(vocabularyProvider.notifier)
                        .markBatchKnown(words, targetLanguage);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "I'll handle them manually",
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}
