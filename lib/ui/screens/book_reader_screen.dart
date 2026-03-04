import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
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
  
  String? _selectedText;
  String? _contextText;
  double? _selectionX;
  double? _selectionY;

  final String _htmlTemplate = """
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.1.5/jszip.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/epubjs/dist/epub.min.js"></script>
    <style>
      body { margin: 0; padding: 0; background-color: #050505; color: #ffffff; overflow: hidden; font-family: sans-serif; }
      #viewer { width: 100vw; height: 100vh; overflow: hidden; }
    </style>
  </head>
  <body>
    <div id="viewer"></div>
    <script>
      let book;
      let rendition;

      async function loadBook(url, initialCfi) {
        console.log("Starting loadBook with URL:", url);
        try {
          if (!url) {
            throw new Error("URL is null or empty");
          }
          
          console.log("Initializing ePub with URL...");
          book = ePub(url);
          
          rendition = book.renderTo("viewer", {
            width: "100%",
            height: "100%",
            spread: "none",
            manager: "continuous",
            flow: "paginated"
          });

          rendition.hooks.content.register(function(contents) {
            console.log("Rendition hook: content registered");
            var style = contents.document.createElement("style");
            style.innerHTML = "body { color: #ffffff !important; background-color: transparent !important; font-size: 1.15em; font-family: sans-serif; line-height: 1.6; } a { color: #6366F1 !important; } ::selection { background: rgba(99, 102, 241, 0.4); }";
            contents.document.head.appendChild(style);
          });

          rendition.on("relocated", function(location) {
            const pct = location.start.percentage ? Math.round(location.start.percentage * 100) : 0;
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('onProgress', location.start.cfi, pct);
            }
          });

          rendition.on("selected", function(cfiRange, contents) {
            book.getRange(cfiRange).then(function(range) {
              const selectedText = range.toString().trim();
              const contextText = range.commonAncestorContainer.textContent || selectedText;
              
              const rect = range.getBoundingClientRect();
              const iframe = contents.document.defaultView.frameElement;
              const iframeRect = iframe.getBoundingClientRect();
              
              const x = rect.left + iframeRect.left + (rect.width / 2);
              const y = rect.bottom + iframeRect.top;
              
              if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('onTextSelected', selectedText, contextText, x, y);
              }
            });
          });

          rendition.on("click", function() {
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('onClearSelection');
            }
          });

          console.log("Displaying rendition...");
          await rendition.display(initialCfi || undefined);
          console.log("Rendition displayed successfully");
          
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('onReady');
          }

          book.ready.then(() => {
            console.log("Book is ready, generating locations...");
            return book.locations.generate(1600);
          });
        } catch(e) {
          console.error("Error in loadBook:", e);
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('onError', e.toString() + " | Stack: " + e.stack);
          }
        }
      }

      window.nextPage = function() { if(rendition) rendition.next(); };
      window.prevPage = function() { if(rendition) rendition.prev(); };
    </script>
  </body>
  </html>
  """;

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookDetailProvider(widget.bookId));
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: LiquidTheme.background,
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.white))),
        data: (book) {
          return SafeArea(
            child: Stack(
              children: [
                Column(
                  children:[
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        children:[
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => context.pop(),
                          ),
                          Expanded(
                            child: Text(
                              book.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text("${_progress.round()}% Read", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children:[
                          InAppWebView(
                            initialData: InAppWebViewInitialData(
                              data: _htmlTemplate,
                              baseUrl: WebUri("https://localhost/"),
                            ),
                            initialSettings: InAppWebViewSettings(
                              transparentBackground: true,
                              disableContextMenu: true,
                              allowFileAccessFromFileURLs: true,
                              allowUniversalAccessFromFileURLs: true,
                            ),
                            onWebViewCreated: (controller) {
                              webViewController = controller;

                              controller.addJavaScriptHandler(handlerName: 'onError', callback: (args) {
                                debugPrint("EPUB ERROR: ${args[0]}");
                              });

                              controller.addJavaScriptHandler(handlerName: 'onReady', callback: (args) {
                                debugPrint("EPUB READY");
                              });

                              controller.addJavaScriptHandler(handlerName: 'onProgress', callback: (args) {
                                final cfi = args[0] as String;
                                final pct = (args[1] as num).toDouble();
                                setState(() {
                                  _progress = pct;
                                });
                                ref.read(bookNotifierProvider.notifier).updateProgress(book.id, cfi, pct);
                              });

                              controller.addJavaScriptHandler(handlerName: 'onTextSelected', callback: (args) {
                                setState(() {
                                  _selectedText = args[0];
                                  _contextText = args[1];
                                  _selectionX = (args[2] as num).toDouble();
                                  _selectionY = (args[3] as num).toDouble();
                                });
                              });

                              controller.addJavaScriptHandler(handlerName: 'onClearSelection', callback: (args) {
                                setState(() {
                                  _selectedText = null;
                                  _contextText = null;
                                });
                              });
                            },
                            onConsoleMessage: (controller, consoleMessage) {
                              debugPrint(
                                "WEBVIEW CONSOLE: ${consoleMessage.message}",
                              );
                            },
                            onLoadStop: (controller, url) async {
                              if (book.signedUrl != null) {
                                await controller.evaluateJavascript(source: "loadBook('${book.signedUrl}', '${book.currentCfi ?? ''}');");
                              }
                            },
                          ),
                          Row(
                            children:[
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedText = null);
                                    webViewController?.evaluateJavascript(source: "window.prevPage();");
                                  },
                                  child: Container(color: Colors.transparent),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(color: Colors.transparent),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedText = null);
                                    webViewController?.evaluateJavascript(source: "window.nextPage();");
                                  },
                                  child: Container(color: Colors.transparent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_selectedText != null && _selectionX != null && _selectionY != null && profileAsync.value != null)
                  TranslationTooltip(
                    selectedText: _selectedText!,
                    contextText: _contextText ?? _selectedText!,
                    sourceLang: book.targetLanguage, 
                    targetLang: profileAsync.value!.nativeLanguage ?? 'english',
                    x: _selectionX!,
                    y: _selectionY! + MediaQuery.of(context).padding.top + 60,
                    onClose: () {
                      setState(() {
                        _selectedText = null;
                      });
                      webViewController?.evaluateJavascript(source: "window.getSelection().removeAllRanges();");
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
