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
import '../widgets/translation_tooltip.dart';
import '../../theme/liquid_theme.dart';

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
  
  String? _selectedText;
  String? _contextText;
  double? _selectionX;
  double? _selectionY;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _localFileReady = false;

  Timer? _progressDebounce;
  HttpServer? _localServer;
  int? _localPort;

  // JavaScript function to apply styles dynamically to the EPUB rendition
  void _updateReaderStyles() {
    final colors = {
      'light': {'bg': '#ffffff', 'fg': '#000000'},
      'dark': {'bg': '#121212', 'fg': '#e4e4e4'},
      'sepia': {'bg': '#f4ecd8', 'fg': '#5b4636'},
    }[_theme]!;

    final js = """
      if (rendition) {
        rendition.themes.fontSize("$_fontSize%");
        rendition.themes.register("$_theme", {
          "body": { "background": "${colors['bg']} !important", "color": "${colors['fg']} !important" },
          "p, span, div, h1, h2, h3, h4, h5, h6, a, li, ul, ol, td, th": { "color": "${colors['fg']} !important", "background": "transparent !important" }
        });
        rendition.themes.select("$_theme");
        
        // Force inject into current contents
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
            }
          });
        });
      }
    """;
    webViewController?.evaluateJavascript(source: js);
  }

  void _applyHighlighting() {
    final srs = ref.read(srsProvider).deck;
    final words = srs.map((e) => e.front).toList();
    final js = "window.highlightKnownWords(${jsonEncode(words)});";
    webViewController?.evaluateJavascript(source: js);
  }

  @override
  void initState() {
    super.initState();
    _startLocalServer();
  }

  Future<void> _startLocalServer() async {
    try {
      _localServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      if (mounted) setState(() => _localPort = _localServer!.port);
      
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
    } catch (e) {
      debugPrint("Local server error: $e");
    }
  }

  @override
  void dispose() {
    _progressDebounce?.cancel();
    _localServer?.close(force: true);
    super.dispose();
  }

  Future<void> _ensureBookDownloaded(UserBook book) async {
    if (_isDownloading || _localFileReady) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${dir.path}/books');
      if (!await booksDir.exists()) await booksDir.create(recursive: true);

      final file = File('${booksDir.path}/${book.id}.epub');
      if (await file.exists()) {
        if (mounted) setState(() => _localFileReady = true);
        return;
      }

      if (book.signedUrl == null) throw Exception("No download URL provided");

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
          if (mounted) {
            setState(() {
              _isDownloading = false;
              _localFileReady = true;
            });
          }
        },
        onError: (e) {
          if (mounted) setState(() => _isDownloading = false);
          debugPrint("Download error: $e");
        },
      );
    } catch (e) {
      if (mounted) setState(() => _isDownloading = false);
      debugPrint("Setup local book error: $e");
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

      window.highlightKnownWords = function(words) {
        if (!rendition) return;
        rendition.getContents().forEach(content => {
          const doc = content.document;
          if (words.length === 0) return;
          const regex = new RegExp('\\\\b(' + words.join('|') + ')\\\\b', 'gi');
          
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
          console.log("Starting loadBook with URL: " + url);
          book = ePub(url);
          rendition = book.renderTo("viewer", { width: "100%", height: "100%", flow: "paginated", manager: "continuous" });
          
          rendition.on("relocated", (location) => {
            const pct = location.start.percentage ? Math.round(location.start.percentage * 100) : 0;
            window.flutter_inappwebview.callHandler('onProgress', location.start.cfi, pct);
          });

          rendition.on("selected", (cfiRange, contents) => {
            book.getRange(cfiRange).then(range => {
              const rect = range.getBoundingClientRect();
              const iframe = contents.document.defaultView.frameElement.getBoundingClientRect();
              window.flutter_inappwebview.callHandler('onTextSelected', range.toString(), range.commonAncestorContainer.textContent, rect.left + iframe.left + (rect.width/2), rect.bottom + iframe.top);
            });
          });

          // Swipe Gestures
          let touchStartX = 0;
          rendition.on("touchstart", (e) => { touchStartX = e.changedTouches[0].screenX; });
          rendition.on("touchend", (e) => {
            const touchEndX = e.changedTouches[0].screenX;
            if (touchStartX - touchEndX > 50) rendition.next();
            if (touchEndX - touchStartX > 50) rendition.prev();
          });

          await rendition.display(initialCfi || undefined);
          console.log("Book displayed successfully");
          window.flutter_inappwebview.callHandler('onReady');
        } catch (error) {
          console.error("EPUB Loading Error: " + error.message);
          console.error(error.stack);
        }
      }
    </script>
  </body>
  </html>
  """;

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.bookId));
    final profileAsync = ref.watch(userProfileProvider);

    // Trigger download when book detail is loaded
   
    bookAsync.whenData((book) {
      if (!_localFileReady && !_isDownloading) {
        Future.microtask(() => _ensureBookDownloaded(book));
      }
    });

    return Scaffold(
      backgroundColor: _theme == 'dark' ? const Color(0xFF121212) : (_theme == 'sepia' ? const Color(0xFFf4ecd8) : Colors.white),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text("${_progress.round()}% Read", style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (book) {
          if (_isDownloading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  const CircularProgressIndicator(color: LiquidTheme.primaryAccent),
                  const SizedBox(height: 16),
                  Text("Downloading Book... ${(_downloadProgress * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white70)),
                ]
              )
            );
          }

          if (!_localFileReady || _localPort == null) {
            return const Center(child: CircularProgressIndicator(color: LiquidTheme.primaryAccent));
          }

          return Stack(
          children:[
            Positioned.fill(
              child: InAppWebView(
                initialData: InAppWebViewInitialData(data: _htmlTemplate, baseUrl: WebUri("http://127.0.0.1:$_localPort/")),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  isInspectable: kDebugMode,
                  allowUniversalAccessFromFileURLs: true,
                  allowFileAccessFromFileURLs: true,
                ),
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint("WEBVIEW: " + consoleMessage.message.toString());
              },
              onWebViewCreated: (controller) {
                webViewController = controller;

                controller.addJavaScriptHandler(handlerName: 'onProgress', callback: (args) {
                  final cfi = args[0] as String;
                  final pct = (args[1] as num).toDouble();
                  if (mounted) setState(() => _progress = pct);
                  
                  _progressDebounce?.cancel();
                  _progressDebounce = Timer(const Duration(seconds: 2), () {
                    ref.read(bookNotifierProvider.notifier).updateProgress(book.id, cfi, pct);
                  });

                  _applyHighlighting(); // Re-apply highlighting on page change
                  _updateReaderStyles(); // Ensure styles are applied to new content
                });
                controller.addJavaScriptHandler(handlerName: 'onReady', callback: (_) {
                  ref.read(srsProvider.notifier).loadDeck(book.targetLanguage); // Ensure deck is loaded
                  _updateReaderStyles();
                  _applyHighlighting();
                });
                controller.addJavaScriptHandler(handlerName: 'onTextSelected', callback: (args) {
                  setState(() { _selectedText = args[0]; _contextText = args[1]; _selectionX = (args[2] as num).toDouble(); _selectionY = (args[3] as num).toDouble(); });
                });
              },
              onLoadStop: (controller, _) async {
                if (_localPort != null) {
                   final localUrl = "http://127.0.0.1:$_localPort/books/${book.id}.epub";
                   await controller.evaluateJavascript(source: "loadBook('$localUrl', '${book.currentCfi ?? ''}');");
                }
              },
            ),
            if (_selectedText != null && profileAsync.value != null)
              TranslationTooltip(
                selectedText: _selectedText!,
                contextText: _contextText ?? _selectedText!,
                sourceLang: book.targetLanguage,
                targetLang: profileAsync.value!.nativeLanguage ?? 'english',
                x: _selectionX!, y: _selectionY!,
                onClose: () => setState(() => _selectedText = null),
              ),
          ],
        );
       },
      ),
    );
  }

  void _showSettings(BuildContext context) {
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
                  onTap: () { setState(() => _theme = t); setModalState((){}); _updateReaderStyles(); },
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
                      onChanged: (v) { setState(() => _fontSize = v); setModalState((){}); _updateReaderStyles(); },
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
}
