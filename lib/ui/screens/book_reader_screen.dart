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

class _BookReaderScreenState extends ConsumerState<BookReaderScreen>
    with WidgetsBindingObserver {
  InAppWebViewController? webViewController;
  WebMessagePort? _vocabPort;
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

  HttpServer? _localServer;
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

  void _postToWeb(String type, dynamic payload) {
    if (_vocabPort != null) {
      try {
        _vocabPort!.postMessage(
          WebMessage(data: {'type': type, 'payload': payload}),
        );
      } catch (e) {
        final logger = ref.read(loggerProvider);
        logger.warning('BookReader: Failed to post message to web: $e');
      }
    }
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
    _postToWeb('UPDATE_THEME', {
      'colors': colors,
      'fontSize': _fontSize,
      'themeName': _theme,
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

          // NEW: Get current vocab and inject it dynamically into the server response
          final currentVocab = ref.read(vocabularyProvider).value ?? {};
          final String injectedHtml = bookReaderHtmlTemplate.replaceFirst(
            'window.vocabMap = {};',
            'window.vocabMap = ${jsonEncode(currentVocab)};',
          );

          request.response.write(injectedHtml);
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
    _postToWeb('SHUTDOWN', null);
    _vocabPort?.close().catchError((_) {});
    _vocabPort = null;
    _localServer?.close(force: true);
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
          _lastSavedCfi =
              book.currentCfi; // Sync state to avoid over-saving initial load
          _initialCfiOnReady =
              book.currentCfi; // Set initial CFI to compare against
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
      if (next.delta != null && _vocabPort != null) {
        _vocabPort!.postMessage(
          WebMessage(data: {'type': 'vocab_delta', 'delta': next.delta}),
        );
        // Clear delta after sending to prevent duplicates
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
                          content: Text(
                            "Marked ${words.length} words as known",
                          ),
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
                            baseUrl: WebUri(
                              "/",
                            ), // Grants a proper origin context vs "null"
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
                    onWebViewCreated: (controller) async {
                      webViewController = controller;
                      logger.info('BookReader: WebView created');

                      _portReadyCompleter = Completer<void>();

                      final channel = await controller
                          .createWebMessageChannel();
                      _vocabPort = channel!.port1;

                      await controller.postWebMessage(
                        message: WebMessage(
                          data: 'capture_port',
                          ports: [channel.port2],
                        ),
                      );

                      controller.addJavaScriptHandler(
                        handlerName: 'onProgress',
                        callback: (args) {
                          if (!mounted) return;

                          final cfi = args[0] as String;
                          final pct = (args[1] as num).toDouble();

                          if (pct == 0 &&
                              widget.initialProgress > 0 &&
                              !_canSaveToBackend) {
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
                            // Get words that WERE visible on the page we just left
                            webViewController
                                ?.evaluateJavascript(
                                  source: "window.getVisibleUnknownWords();",
                                )
                                .then((wordsObj) {
                                  if (wordsObj != null && wordsObj is List) {
                                    final words = wordsObj
                                        .map((e) => e.toString())
                                        .toList();
                                    logger.info(
                                      'BookReader: Visible unknown words returned: ${words.length}',
                                    );
                                    if (words.isNotEmpty) {
                                      _triggerVocabReview(words);
                                    }
                                  } else {
                                    logger.info(
                                      'BookReader: Visible unknown words returned: none/invalid',
                                    );
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
                          if (_initialCfiOnReady != null &&
                              cfi == _initialCfiOnReady) {
                            logger.info(
                              'BookReader: Skipping save - at initial position: $cfi',
                            );
                            return;
                          }

                          if (mounted && _lastCfi != _lastSavedCfi) {
                            final progressToSave = acceptProgress
                                ? _progress
                                : _progress;
                            logger.info(
                              'BookReader: Saving progress - CFI: $_lastCfi, Progress: $progressToSave% (acceptProgress: $acceptProgress)',
                            );
                            _progressDebounce?.cancel();
                            _progressDebounce = Timer(
                              const Duration(milliseconds: 500),
                              () {
                                if (!mounted) return;
                                ref
                                    .read(bookNotifierProvider.notifier)
                                    .updateProgress(
                                      widget.bookId,
                                      _lastCfi!,
                                      progressToSave,
                                    );
                                _lastSavedCfi = _lastCfi;
                              },
                            );
                          }

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
                        callback: (_) async {
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

                          if (!mounted || _vocabPort == null) return;

                          _postToWeb('PORT_READY', null);

                          if (book.locations != null &&
                              book.locations!.length > 5) {
                            _postToWeb('SET_LOCATIONS', book.locations);
                          }

                          final vocabData = await ref
                              .read(vocabularyProvider.notifier)
                              .getVocabulary(book.targetLanguage);
                          if (mounted &&
                              _vocabPort != null &&
                              vocabData.isNotEmpty) {
                            _vocabPort!.postMessage(
                              WebMessage(
                                data: {
                                  'type': 'vocab_delta',
                                  'delta': vocabData,
                                },
                              ),
                            );
                          }
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

                      controller.addJavaScriptHandler(
                        handlerName: 'onLocationsGenerated',
                        callback: (args) {
                          final String locationsJson = args[0] as String;

                          // NEW CODE START: Prevent syncing empty arrays
                          if (locationsJson == "[]" || locationsJson.isEmpty) {
                            logger.warning(
                              'BookReader: Received empty locations from JS, skipping sync.',
                            );
                            return;
                          }
                          // NEW CODE END

                          logger.info(
                            'BookReader: Received generated locations from JS. Size: ${locationsJson.length}',
                          );

                          // Call the notifier to save this to the backend
                          ref
                              .read(bookNotifierProvider.notifier)
                              .updateLocations(widget.bookId, locationsJson);
                        },
                      );
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
                        final jsCall =
                            """
                          loadBook({
                            url: ${jsonEncode(bookUrl)},
                            initialCfi: ${jsonEncode(_lastCfi ?? '')},
                            theme: ${jsonEncode(colors)},
                            themeName: ${jsonEncode(_theme)},
                            fontSize: $_fontSize,
                            vocabMap: null
                          });
                        """;
                        await controller.evaluateJavascript(source: jsCall);
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

    final book = ref.read(bookDetailProvider(widget.bookId)).value;
    if (book == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _VocabularyReviewSheet(
        words: words,
        targetLanguage: book.targetLanguage,
        webViewController: webViewController,
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
  StreamSubscription? _translationSub;
  bool _isFinal = false;
  String? _contextualTranslation;
  String? _explanation;
  bool _isAdding = false;
  bool _isAdded = false;

  @override
  void initState() {
    super.initState();
    _startHybridTranslation();
  }

  void _startHybridTranslation() {
    _translationSub = ref
        .read(aiServiceProvider)
        .streamContextualTranslation(
          selectedText: widget.selectedText,
          context: widget.contextText,
          sourceLanguage: widget.sourceLang,
          targetLanguage: widget.targetLang,
        )
        .listen((data) {
          if (mounted) {
            setState(() {
              _contextualTranslation = data['translation'];
              _explanation = data['explanation'];
              _isFinal = data['isFinal'] ?? false;
            });
          }
        });
  }

  @override
  void dispose() {
    _translationSub?.cancel();
    super.dispose();
  }

  Future<void> _handleAddToDeck() async {
    setState(() => _isAdding = true);
    final success = await ref
        .read(srsProvider.notifier)
        .addToDeckFromTranslation(
          front: widget.selectedText,
          back: _contextualTranslation!,
          language: widget.sourceLang,
          explanation: _explanation,
        );

    if (mounted) {
      setState(() {
        _isAdding = false;
        if (success) {
          _isAdded = true;
          // NEW: Trigger local vocab update so the word color changes in the background
          ref
              .read(vocabularyProvider.notifier)
              .updateWordStatus(
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

          // Progress indicator while not final
          if (!_isFinal)
            const LinearProgressIndicator(
              minHeight: 2,
              color: LiquidTheme.primaryAccent,
            )
          else
            const SizedBox(height: 2),

          const SizedBox(height: 8),

          if (_contextualTranslation != null)
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
            )
          else
            const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(
                  color: LiquidTheme.secondaryAccent,
                ),
              ),
            ),

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
              onPressed: (!_isFinal || _isAdded || _isAdding)
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

class _VocabularyReviewSheet extends ConsumerStatefulWidget {
  final List<String> words;
  final String targetLanguage;
  final InAppWebViewController? webViewController;

  const _VocabularyReviewSheet({
    required this.words,
    required this.targetLanguage,
    this.webViewController,
  });

  @override
  ConsumerState<_VocabularyReviewSheet> createState() =>
      _VocabularyReviewSheetState();
}

class _VocabularyReviewSheetState
    extends ConsumerState<_VocabularyReviewSheet> {
  late List<String> _pendingWords;

  @override
  void initState() {
    super.initState();
    _pendingWords = List.from(widget.words);
  }

  void _removeWord(String word) {
    setState(() {
      _pendingWords.remove(word);
    });
    if (_pendingWords.isEmpty) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${_pendingWords.length} New Words",
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
              itemCount: _pendingWords.length,
              itemBuilder: (context, i) => _VocabListItem(
                word: _pendingWords[i],
                targetLanguage: widget.targetLanguage,
                webViewController: widget.webViewController,
                onMarkKnown: () {
                  // Update Remote + Provider state (delta will be sent via port listener)
                  ref
                      .read(vocabularyProvider.notifier)
                      .updateWordStatus(
                        _pendingWords[i],
                        'known',
                        widget.targetLanguage,
                      );
                  // Remove from UI list
                  _removeWord(_pendingWords[i]);
                },
                onAddedToDeck: () {
                  // Update Remote + Provider state (delta will be sent via port listener)
                  ref
                      .read(vocabularyProvider.notifier)
                      .updateWordStatus(
                        _pendingWords[i],
                        'learning',
                        widget.targetLanguage,
                      );
                  _removeWord(_pendingWords[i]);
                },
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
                        .markBatchKnown(_pendingWords, widget.targetLanguage);
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

class _VocabListItem extends ConsumerStatefulWidget {
  final String word;
  final String targetLanguage;
  final InAppWebViewController? webViewController;
  final VoidCallback onMarkKnown;
  final VoidCallback onAddedToDeck;

  const _VocabListItem({
    required this.word,
    required this.targetLanguage,
    this.webViewController,
    required this.onMarkKnown,
    required this.onAddedToDeck,
  });

  @override
  ConsumerState<_VocabListItem> createState() => _VocabListItemState();
}

class _VocabListItemState extends ConsumerState<_VocabListItem> {
  bool _expanded = false;
  bool _loading = false;
  String? _translation;

  void _toggle() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && _translation == null) {
      setState(() => _loading = true);
      try {
        final nativeLang =
            ref.read(userProfileProvider).value?.nativeLanguage ?? 'english';
        final res = await ref
            .read(aiServiceProvider)
            .translate(widget.word, widget.targetLanguage, nativeLang);
        if (mounted) {
          setState(() {
            _translation = res;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _translation = "Error translating";
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              widget.word,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onTap: _toggle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.greenAccent),
                  onPressed: widget.onMarkKnown,
                  tooltip: "Mark Known",
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: LiquidTheme.primaryAccent),
                  onPressed: () async {
                    if (_translation == null) {
                      setState(() => _loading = true);
                      try {
                        final nativeLang =
                            ref
                                .read(userProfileProvider)
                                .value
                                ?.nativeLanguage ??
                            'english';
                        final res = await ref
                            .read(aiServiceProvider)
                            .translate(
                              widget.word,
                              widget.targetLanguage,
                              nativeLang,
                            );
                        _translation = res;
                      } catch (e) {
                        _translation = "Unknown";
                      }
                    }
                    if (mounted) {
                      ref
                          .read(srsProvider.notifier)
                          .addToDeckFromTranslation(
                            front: widget.word,
                            back: _translation!,
                            language: widget.targetLanguage,
                          );
                      widget.onAddedToDeck();
                    }
                  },
                  tooltip: "Add to Deck",
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.subdirectory_arrow_right,
                          size: 16,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _translation ?? "Error",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
