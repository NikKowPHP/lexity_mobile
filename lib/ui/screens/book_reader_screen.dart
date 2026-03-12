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
import '../../services/logger_service.dart';
import '../../theme/liquid_theme.dart';
import '../../services/ai_service.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  InAppWebViewController? webViewController;
  double _progress = 0.0;
  double _fontSize = 115.0;
  String _theme = 'dark'; // 'light', 'dark', 'sepia'
  String? _lastCfi;
  List<dynamic> _toc = [];

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _localFileReady = false;

  Timer? _progressDebounce;
  HttpServer? _localServer;
  int? _localPort;

  bool _isInitialized = false;
  
  // Flag to prevent early '0%' percentage reports from overwriting DB progress
  bool _canSaveToBackend = false;

  void _updateReaderStyles() {
    final logger = ref.read(loggerProvider);
    logger.debug('BookReader: Updating styles (Theme: $_theme, Size: $_fontSize%)');
    
    final colors = {
      'light': {'bg': '#ffffff', 'fg': '#000000'},
      'dark': {'bg': '#121212', 'fg': '#e4e4e4'},
      'sepia': {'bg': '#f4ecd8', 'fg': '#5b4636'},
    }[_theme]!;

    final js = """
      if (typeof rendition !== 'undefined' && rendition) {
        rendition.themes.fontSize("$_fontSize%");
        rendition.themes.register("$_theme", {
          "body": { "background": "${colors['bg']} !important", "color": "${colors['fg']} !important" },
          "p, span, div, h1, h2, h3, h4, h5, h6, a, li, ul, ol, td, th": { "color": "${colors['fg']} !important", "background": "transparent !important" },
          "::selection": { "background": "rgba(99, 102, 241, 0.3) !important", "text-decoration": "underline !important" }
        });
        rendition.themes.select("$_theme");
        
        rendition.getContents().forEach(c => {
          c.addStylesheetRules({
            "body": {
              "background-color": "${colors['bg']} !important",
              "color": "${colors['fg']} !important",
              "font-size": "$_fontSize% !important"
            },
            "p, span, div, h1, h2, h3, h4, h5, h6, a, li, ul, ol, td, th": {
              "color": "${colors['fg']} !important",
              "background": "transparent !important"
            },
            "::selection": {
              "background-color": "rgba(99, 102, 241, 0.3) !important",
              "text-decoration": "underline !important",
              "text-decoration-color": "#6366F1 !important",
              "color": "inherit !important"
            }
          });
        });
      }
    """;
    webViewController?.evaluateJavascript(source: js);
  }

  void _applyHighlighting() {
    final logger = ref.read(loggerProvider);
    final srs = ref.read(srsProvider).deck;
    final words = srs.map((e) => e.front).toList();
    
    logger.debug('BookReader: Applying highlighting for ${words.length} known words');
    final js = "if (window.highlightKnownWords) window.highlightKnownWords(${jsonEncode(words)});";
    webViewController?.evaluateJavascript(source: js);
  }

  @override
  void initState() {
    super.initState();
    _startLocalServer();
  }

  Future<void> _startLocalServer() async {
    final logger = ref.read(loggerProvider);
    logger.info('BookReader: Initializing local file server');
    try {
      _localServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (mounted) {
        setState(() => _localPort = _localServer!.port);
        logger.info('BookReader: Local server bound to port $_localPort');
      }
      
      _localServer!.listen((HttpRequest request) async {
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Access-Control-Allow-Methods', 'GET, OPTIONS');
        request.response.headers.add('Access-Control-Allow-Headers', '*');
        
        if (request.method == 'OPTIONS') {
           request.response.statusCode = 200;
           await request.response.close();
           return;
        }
        if (request.uri.path.startsWith('/books/')) {
           final bookId = request.uri.pathSegments.last.replaceAll('.epub', '');
           final dir = await getApplicationDocumentsDirectory();
           final file = File('${dir.path}/books/$bookId.epub');
           
           if (await file.exists()) {
             logger.debug('BookReader: Serving local EPUB file for $bookId');
             final length = await file.length();
             request.response.contentLength = length;
             request.response.headers.contentType = ContentType('application', 'epub+zip', charset: 'utf-8');
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

      logger.info('BookReader: Book not found locally, starting download for "${book.title}"');
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
          if (total > 0 && mounted) setState(() => _downloadProgress = received / total);
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

  final String _htmlTemplate = """
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.1.5/jszip.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/epubjs/dist/epub.min.js"></script>
    <style>
      html, body { margin: 0; padding: 0; width: 100%; height: 100%; background-color: transparent; overflow: hidden; }
      #viewer { width: 100%; height: 100%; position: absolute; top: 0; left: 0; right: 0; bottom: 0; }
      mark.known-word { background-color: rgba(99, 102, 241, 0.3) !important; border-bottom: 2px dotted #6366F1 !important; color: inherit !important; }
    </style>
  </head>
  <body>
    <div id="viewer"></div>
    <script>
      let book;
      let rendition;
      window.lastReportedText = "";

      window.highlightKnownWords = function(words) {
        if (!rendition) return;
        rendition.getContents().forEach(content => {
          const doc = content.document;
          if (words.length === 0) return;
          // Escape for Regex
          const escapeRegExp = (s) => s.replace(/[.*+?^\\\$${"{"}}()|[\\\]\\\\]/g, '\\\\\$&');
          const regex = new RegExp('\\\\b(' + words.map(escapeRegExp).join('|') + ')\\\\b', 'gi');
          
          const walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT);
          let node;
          const nodes = [];
          while (node = walker.nextNode()) nodes.push(node);
          
          nodes.forEach(textNode => {
            if (textNode.parentNode && textNode.parentNode.nodeName.toLowerCase() === 'mark') return;
            if (regex.test(textNode.nodeValue)) {
              const span = doc.createElement('span');
              span.innerHTML = textNode.nodeValue.replace(regex, '<mark class="known-word">\$1</mark>');
              textNode.parentNode.replaceChild(span, textNode);
            }
          });
        });
      };

      async function loadBook(url, initialCfi) {
        try {
          console.log("BookReader JS: Initializing ePub.js engine");
          book = ePub(url);
          
          await book.opened;
          console.log("BookReader JS: Book opened");

          rendition = book.renderTo("viewer", { 
            width: "100%", 
            height: "100%", 
            flow: "paginated", 
            manager: "continuous" 
          });
          
          rendition.on("relocated", (location) => {
            // Percent is only valid after locations.generate()
            const pct = location.start.percentage ? Math.round(location.start.percentage * 100) : 0;
            window.flutter_inappwebview.callHandler('onProgress', location.start.cfi, pct);
          });

          function checkAndReportSelection(win) {
              if (!win) return;
              const sel = win.getSelection();
              if (!sel) return;
              
              const text = sel.toString().trim();
              if (text.length > 0 && text !== window.lastReportedText) {
                  window.lastReportedText = text;
                  let contextText = text;
                  if (sel.rangeCount > 0) {
                      let container = sel.getRangeAt(0).commonAncestorContainer;
                      if (container && container.nodeType === 3) container = container.parentNode;
                      if (container) contextText = container.textContent.trim();
                  }
                  window.flutter_inappwebview.callHandler('onTextSelected', text, contextText);
              } else if (text.length === 0) {
                  window.lastReportedText = "";
              }
          }

          let selectionTimeout = null;
          rendition.hooks.content.register((contents) => {
            const win = contents.window;
            const doc = contents.document;
            
            doc.addEventListener('selectionchange', () => {
              clearTimeout(selectionTimeout);
              selectionTimeout = setTimeout(() => checkAndReportSelection(win), 800);
            });

            doc.addEventListener('touchend', () => {
              setTimeout(() => checkAndReportSelection(win), 150);
            });
          });

          let touchStartX = 0;
          rendition.on("touchstart", (e) => { touchStartX = e.changedTouches[0].screenX; });
          rendition.on("touchend", (e) => {
            const dx = touchStartX - e.changedTouches[0].screenX;
            if (Math.abs(dx) > 50) {
              if (dx > 0) rendition.next();
              else rendition.prev();
            } 
          });

          console.log("BookReader JS: Displaying position: " + initialCfi);
          await rendition.display(initialCfi || undefined);
          window.flutter_inappwebview.callHandler('onReady');
          
          await book.ready;
          console.log("BookReader JS: Generating locations...");
          await book.locations.generate(1600);
          console.log("BookReader JS: Locations ready.");

          // RECURSIVE TOC EXTRACTION
          const flattenToc = (items, level = 0) => {
            return items.reduce((acc, item) => {
              acc.push({
                label: item.label,
                href: item.href,
                level: level
              });
              if (item.subitems && item.subitems.length > 0) {
                acc.push(...flattenToc(item.subitems, level + 1));
              }
              return acc;
            }, []);
          };

          const toc = flattenToc(book.navigation.toc);
          window.flutter_inappwebview.callHandler('onToc', toc);

          const loc = rendition.currentLocation();
          if (loc && loc.start) {
              const pct = loc.start.percentage ? Math.round(loc.start.percentage * 100) : 0;
              window.flutter_inappwebview.callHandler('onProgress', loc.start.cfi, pct);
          }
        } catch (error) {
          console.error("EPUB Loading Error: " + error.message);
        }
      }
    </script>
  </body>
  </html>
  """;

  Future<void> _handleImmediateSave() async {
    final logger = ref.read(loggerProvider);
    if (_lastCfi != null && mounted) {
      logger.info('BookReader: Performing immediate progress save on screen exit. CFI: $_lastCfi');
      await ref.read(bookNotifierProvider.notifier).updateProgress(widget.bookId, _lastCfi!, _progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.bookId));
    final profileAsync = ref.watch(userProfileProvider);
    final logger = ref.read(loggerProvider);

    bookAsync.whenData((book) {
      if (!_isInitialized) {
          logger.info('BookReader: Initializing state from DB. Saved CFI: ${book.currentCfi}');
          _isInitialized = true;
          setState(() {
            _progress = book.progressPct;
            _lastCfi = book.currentCfi;
          });
          _ensureBookDownloaded(book);
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
          if (didPop) {
             _handleImmediateSave();
          }
      },
      child: Scaffold(
        backgroundColor: _theme == 'dark' ? const Color(0xFF121212) : (_theme == 'sepia' ? const Color(0xFFf4ecd8) : Colors.white),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
            logger.info('BookReader: Exiting reader');
            context.pop();
          }),
          title: Text("${_progress.round()}% Read", style: const TextStyle(fontSize: 14)),
          actions: [
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
        body: bookAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) {
            logger.error('BookReader: Failed to load book data', e, st);
            return Center(child: Text("Error: $e"));
          },
          data: (book) {
            if (_isDownloading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:[
                    const CircularProgressIndicator(color: LiquidTheme.primaryAccent),
                    const SizedBox(height: 16),
                    Text("Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white70)),
                  ]
                )
              );
            }
      
            if (!_localFileReady || _localPort == null) {
              return const Center(child: CircularProgressIndicator(color: LiquidTheme.primaryAccent));
            }
      
            return InAppWebView(
              initialData: InAppWebViewInitialData(
                data: _htmlTemplate, 
                baseUrl: WebUri("http://127.0.0.1:$_localPort/")
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                isInspectable: kDebugMode,
                allowUniversalAccessFromFileURLs: true,
                allowFileAccessFromFileURLs: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;
                controller.addJavaScriptHandler(handlerName: 'onProgress', callback: (args) {
                  final cfi = args[0] as String;
                  final pct = (args[1] as num).toDouble();
                  
                  if (mounted) {
                    setState(() {
                      if (pct > 0) _progress = pct;
                      _lastCfi = cfi;
                    });
                  }

                  if (!_canSaveToBackend && pct <= 0) {
                      return;
                  }

                  logger.debug('BookReader JS: Progress callback received. CFI: $cfi, Pct: $pct%');
                  
                  _progressDebounce?.cancel();
                  _progressDebounce = Timer(const Duration(milliseconds: 1500), () {
                    if (mounted) {
                      logger.info('BookReader: Saving progress to server: $cfi ($pct%)');
                      ref.read(bookNotifierProvider.notifier).updateProgress(book.id, cfi, pct);
                    }
                  });

                  _updateReaderStyles();
                  _applyHighlighting();
                });

                controller.addJavaScriptHandler(handlerName: 'onToc', callback: (args) {
                  final tocData = args[0] as List<dynamic>;
                  logger.info('BookReader JS: TOC received, ${tocData.length} items');
                  if (mounted) setState(() => _toc = tocData);
                });

                controller.addJavaScriptHandler(handlerName: 'onReady', callback: (_) {
                  logger.info('BookReader JS: Rendition ready. Unblocking backend saves.');
                  
                  Future.delayed(const Duration(milliseconds: 2000), () {
                    if (mounted) setState(() => _canSaveToBackend = true);
                  });

                  ref.read(srsProvider.notifier).loadDeck(book.targetLanguage);
                  _updateReaderStyles();
                  _applyHighlighting();
                });

                controller.addJavaScriptHandler(handlerName: 'onTextSelected', callback: (args) {
                  _showTranslationSheet(
                    context, 
                    selectedText: args[0].toString(), 
                    contextText: args[1].toString(), 
                    sourceLang: book.targetLanguage, 
                    nativeLang: profileAsync.value?.nativeLanguage ?? 'english',
                  );
                });
              },
              onLoadStop: (controller, _) async {
                if (_localPort != null) {
                   final localUrl = "http://127.0.0.1:$_localPort/books/${book.id}.epub";
                   logger.info('BookReader: Injecting load command. CFI: $_lastCfi');
                   final jsCall = "loadBook(${jsonEncode(localUrl)}, ${jsonEncode(_lastCfi ?? '')});";
                   await controller.evaluateJavascript(source: jsCall);
                }
              },
            );
         },
        ),
      ),
    );
  }

  void _showChapterBrowser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              child: Text("Table of Contents", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: _toc.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final chapter = _toc[index];
                  final int level = chapter['level'] ?? 0;
                  
                  return ListTile(
                    contentPadding: EdgeInsets.only(left: 16.0 + (level * 16.0), right: 16.0),
                    title: Text(
                      chapter['label'].toString().trim(), 
                      style: TextStyle(
                        color: level == 0 ? Colors.white : Colors.white70,
                        fontWeight: level == 0 ? FontWeight.bold : FontWeight.normal,
                        fontSize: level == 0 ? 15 : 14,
                      )
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
                    onTap: () {
                      final href = chapter['href'].toString();
                      
                      webViewController?.evaluateJavascript(source: "rendition.display('${href}');");
                      Navigator.pop(context);
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
    final logger = ref.read(loggerProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Appearance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['light', 'dark', 'sepia'].map((t) => GestureDetector(
                  onTap: () { 
                    logger.info('BookReader: Switched theme to $t');
                    setState(() => _theme = t); 
                    setModalState((){}); 
                    _updateReaderStyles(); 
                  },
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: t == 'light' ? Colors.white : (t == 'sepia' ? const Color(0xFFf4ecd8) : const Color(0xFF333333)),
                      shape: BoxShape.circle,
                      border: Border.all(color: _theme == t ? LiquidTheme.primaryAccent : Colors.transparent, width: 3)
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 16),
                  Expanded(
                    child: Slider(
                      value: _fontSize, min: 80, max: 200,
                      onChanged: (v) { 
                        setState(() => _fontSize = v); 
                        setModalState((){}); 
                      },
                      onChangeEnd: (v) {
                        logger.info('BookReader: Font size settled at ${v.round()}%');
                        _updateReaderStyles();
                      },
                    ),
                  ),
                  const Icon(Icons.text_fields, size: 24),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTranslationSheet(BuildContext context, {required String selectedText, required String contextText, required String sourceLang, required String nativeLang}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _TranslationBottomSheet(
        selectedText: selectedText,
        contextText: contextText,
        sourceLang: sourceLang,
        targetLang: nativeLang,
      ),
    );

    webViewController?.evaluateJavascript(source: """
      if (typeof rendition !== 'undefined' && rendition) {
        rendition.getContents().forEach(c => c.window.getSelection().removeAllRanges());
        window.lastReportedText = "";
      }
    """);
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
  ConsumerState<_TranslationBottomSheet> createState() => _TranslationBottomSheetState();
}

class _TranslationBottomSheetState extends ConsumerState<_TranslationBottomSheet> {
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
      final result = await aiService.translate(widget.selectedText, widget.sourceLang, widget.targetLang);
      if (mounted) setState(() { _fastTranslation = result; _isLoadingFast = false; });
    } catch (e, st) {
      logger.error('BookReader: Fast translation failed', e, st);
      if (mounted) setState(() { _fastTranslation = "Failed to translate"; _isLoadingFast = false; });
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
      if (mounted) setState(() { _isLoadingContext = false; });
    }
  }

  Future<void> _handleAddToDeck() async {
    final logger = ref.read(loggerProvider);
    setState(() => _isAdding = true);
    final success = await ref.read(srsProvider.notifier).addToDeckFromTranslation(
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
          logger.info('BookReader: Added to deck successfully');
        } 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Text(widget.selectedText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          
          if (_isLoadingFast)
            const CircularProgressIndicator()
          else
            Text(_fastTranslation ?? "", style: const TextStyle(fontSize: 18, color: LiquidTheme.primaryAccent, fontWeight: FontWeight.w600)),
            
          const SizedBox(height: 24),
          
          if (_contextualTranslation == null && !_isLoadingContext)
            OutlinedButton.icon(
              onPressed: _fetchContextTranslation,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text("Deep Translate with Context", style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
            )
          else if (_isLoadingContext)
            const Center(child: CircularProgressIndicator(color: LiquidTheme.secondaryAccent))
          else ...[
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
               child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                 Text(_contextualTranslation!, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                 Text(_explanation ?? "", style: const TextStyle(fontSize: 14, color: Colors.white70)),
               ]),
             )
          ],
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdded ? Colors.green.withValues(alpha: 0.2) : LiquidTheme.primaryAccent,
                foregroundColor: _isAdded ? Colors.greenAccent : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: (_isLoadingFast || _isAdded || _isAdding) ? null : _handleAddToDeck,
              icon: _isAdding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_isAdded ? Icons.check : Icons.add),
              label: Text(_isAdded ? "Added to Deck" : "Add to Study Deck", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
