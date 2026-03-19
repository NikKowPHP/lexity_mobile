const String bookReaderHtmlTemplate = """
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.1.5/jszip.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/epubjs/dist/epub.min.js"></script>
  <style>
    html, body { 
      margin: 0; padding: 0; width: 100%; height: 100%; 
      background-color: #121212;
    }
    body.loading #viewer { opacity: 0; }
    #viewer { width: 100%; height: 100%; position: absolute; top: 0; left: 0; right: 0; bottom: 0; opacity: 1; transition: opacity 0.15s ease; }
    mark.known-word { background-color: rgba(99, 102, 241, 0.3) !important; border-bottom: 2px dotted #6366F1 !important; color: inherit !important; }
  </style>
</head>
<body class="loading">
  <div id="viewer"></div>
  <script>
    let book;
    let rendition;
    window.vocabMap = {};
    window.lastReportedText = "";
    window.currentTheme = null;
    window.currentThemeName = 'light';
    window.currentFontSize = 100;
    window.portReady = false;

    function throttle(func, limit) {
      let inThrottle;
      let lastArgs;
      return function(...args) {
        lastArgs = args;
        if (!inThrottle) {
          func.apply(this, args);
          inThrottle = true;
          setTimeout(() => { inThrottle = false; if (lastArgs) func.apply(this, lastArgs); }, limit);
        }
      };
    }

    function dispatchMessage(data) {
      if (!data || !data.type) return;
      switch (data.type) {
        case 'UPDATE_THEME':
          if (data.payload && window.applyTheme) {
            window.applyTheme(data.payload.colors, data.payload.fontSize, data.payload.themeName);
          }
          break;
        case 'SET_LOCATIONS':
          if (data.payload && book && book.locations) {
            try {
              const locPayload = typeof data.payload === 'string' ? JSON.parse(data.payload) : data.payload;
              book.locations.load(locPayload);
              console.log("BookReader JS: Locations loaded via port. Count:", book.locations.length);
            } catch (e) {
              console.warn("BookReader JS: Failed to parse locations from port", e);
            }
          }
          break;
        case 'SHUTDOWN':
          if (rendition) { rendition.destroy(); rendition = null; }
          if (book) { book.destroy(); book = null; }
          console.log("BookReader JS: Shutdown complete");
          break;
        case 'command':
          const cmd = data.payload && data.payload.cmd;
          const cmdData = data.payload && data.payload.data;
          switch (cmd) {
            case 'loadBook':
              if (cmdData && window.loadBook) {
                window.loadBook(cmdData);
              }
              break;
            case 'clearSelection':
              if (typeof rendition !== 'undefined' && rendition) {
                rendition.getContents().forEach(c => c.window.getSelection().removeAllRanges());
                window.lastReportedText = "";
              }
              break;
            case 'displayHref':
              if (cmdData && cmdData.href && typeof rendition !== 'undefined' && rendition) {
                rendition.display(cmdData.href);
              }
              break;
          }
          break;
      }
    }

    window.setReaderVisible = function(isVisible) {
      if (isVisible) document.body.classList.remove('loading');
      else document.body.classList.add('loading');
    };

    // NEW: Safe wrapper for calling the Dart side
    function callFlutter(handlerName, ...args) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        return window.flutter_inappwebview.callHandler(handlerName, ...args);
      }
      return null;
    }

    // NEW: Listen for vocab delta updates via postWebMessage
    window.addEventListener("message", (event) => {
        if (event.data && event.data.type === 'vocab_delta') {
            window.applyVocabStyles(JSON.stringify(event.data.delta));
        }
    });

    // NEW: Listen for the message channel port
    window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {
        window.addEventListener("message", function(event) {
            if (event.data === 'capture_port') {
                window.vocabPort = event.ports[0];
                window.vocabPort.onmessage = function(e) {
                    if (e.data && e.data.type === 'vocab_delta') {
                        window.applyVocabStyles(e.data.delta);
                    } else if (e.data && e.data.type === 'PORT_READY') {
                        window.portReady = true;
                        if (window.vocabPort && window.vocabPort.flushQueue) {
                            window.vocabPort.flushQueue();
                        }
                    } else {
                        dispatchMessage(e.data);
                    }
                };
            }
        });
    });

    window.applyVocabStyles = function(vocabMapJson) {
      if (!rendition) return;
      try {
        const newEntries = typeof vocabMapJson === 'string' 
          ? JSON.parse(vocabMapJson) 
          : vocabMapJson;
        
        // Update our global cache so future pages use these styles
        Object.assign(window.vocabMap, newEntries);
        
        // PERFORMANCE FIX: Batch DOM updates in requestAnimationFrame
        requestAnimationFrame(() => {
          // Only iterate over the DELTA words to avoid O(N) DOM scans
          rendition.getContents().forEach(content => {
            Object.keys(newEntries).forEach(function(word) {
              var selector = '.lexity-word[data-word="' + word + '"]';
              var spans = content.document.querySelectorAll(selector);
              for (var i = 0; i < spans.length; i++) {
                spans[i].className = 'lexity-word ' + newEntries[word].toLowerCase();
              }
            });
          });
        });
      } catch (e) {
        console.error("Error applying vocab styles:", e);
      }
    };

    window.getVisibleUnknownWords = function() {
      if (!rendition) return [];

      const location = rendition.currentLocation && rendition.currentLocation();
      const startCfi = location && location.start ? location.start.cfi : null;
      const endCfi = location && location.end ? location.end.cfi : null;
      console.log("[Lexity][VisibleWords] currentLocation:", location);
      console.log("[Lexity][VisibleWords] startCfi:", startCfi, "endCfi:", endCfi);

      const compareCfi = (() => {
        try {
          if (window.ePub && window.ePub.CFI) {
            if (typeof window.ePub.CFI.compare === 'function') {
              console.log("[Lexity][VisibleWords] Using window.ePub.CFI.compare");
              return (a, b) => window.ePub.CFI.compare(a, b);
            }
            const cfi = new window.ePub.CFI();
            if (cfi && typeof cfi.compare === 'function') {
              console.log("[Lexity][VisibleWords] Using new window.ePub.CFI().compare");
              return (a, b) => cfi.compare(a, b);
            }
          }
          if (window.EPUBJS && window.EPUBJS.EpubCFI) {
            const cfi = new window.EPUBJS.EpubCFI();
            if (cfi && typeof cfi.compare === 'function') {
              console.log("[Lexity][VisibleWords] Using new window.EPUBJS.EpubCFI().compare");
              return (a, b) => cfi.compare(a, b);
            }
          }
        } catch (e) {
          console.warn("CFI compare unavailable:", e);
        }
        console.warn("[Lexity][VisibleWords] No CFI compare available. Falling back to viewport.");
        return null;
      })();

      const visible = [];
      const seen = new Set();

      rendition.getContents().forEach(content => {
        const doc = content.document;
        const spans = doc.querySelectorAll('.lexity-word.unknown');
        let processed = 0;
        spans.forEach(span => {
          const dataWord = span.getAttribute('data-word');
          if (!dataWord) return;
          processed += 1;

          if (compareCfi && startCfi && endCfi && typeof content.cfiFromNode === 'function') {
            const nodeCfi = content.cfiFromNode(span);
            if (!nodeCfi) {
              console.warn("[Lexity][VisibleWords] Missing nodeCfi for word:", dataWord);
              return;
            }
            const cmpStart = compareCfi(nodeCfi, startCfi);
            const cmpEnd = compareCfi(nodeCfi, endCfi);
            if (cmpStart < 0 || cmpEnd > 0) {
              return;
            }
          } else {
            const win = content.window;
            const viewportWidth = win && win.innerWidth ? win.innerWidth : doc.documentElement.clientWidth;
            const viewportHeight = win && win.innerHeight ? win.innerHeight : doc.documentElement.clientHeight;
            const rect = span.getBoundingClientRect();
            if (!(rect.width > 0 && rect.height > 0 &&
                  rect.right > 0 && rect.left < viewportWidth &&
                  rect.bottom > 0 && rect.top < viewportHeight)) {
              return;
            }
          }

          const word = dataWord.toLowerCase();
          if (seen.has(word)) return;
          seen.add(word);
          visible.push(word);
        });
        console.log("[Lexity][VisibleWords] content processed:", {
          totalUnknownSpans: spans.length,
          processed,
          collected: visible.length,
          hasCfiFromNode: typeof content.cfiFromNode === 'function',
          compareCfiAvailable: !!compareCfi
        });
      });

      console.log("[Lexity][VisibleWords] unique visible words:", visible.length);
      return visible;
    };

    function applyThemeToContents(contents) {
      if (!contents || !contents.document || !window.currentTheme) return;
      const c = window.currentTheme;
      const t = window.currentThemeName || 'light';
      const f = window.currentFontSize || 100;
      contents.addStylesheetRules({
          "body": {
              "background-color": c.bg + " !important",
              "color": c.fg + " !important",
              "font-size": f + "% !important"
          },
          "p": {
              "position": "relative !important",
              "padding-right": "40px !important", // Reduced padding for better text balance
              "margin-bottom": "1.5em !important",
              "color": c.fg + " !important",
              "line-height": "1.6 !important"
          },
          "p, span, div, h1, h2, h3, h4, h5, h6, a, li, ul, ol, td, th": {
              "color": c.fg + " !important",
              "background": "transparent !important"
          },
          ".lexity-word": { 
              "cursor": "pointer", 
              "transition": "background-color 0.3s, border-bottom 0.3s" 
          },
          ".lexity-word.unknown": { 
              "background-color": "rgba(99, 102, 241, 0.15) !important",
              "border-bottom": "1px dashed " + (t === 'light' ? 'rgba(0,0,0,0.3)' : 'rgba(255,255,255,0.3)') + " !important" 
          },
          ".lexity-word.learning": { 
              "background-color": "rgba(236, 72, 153, 0.2) !important", 
              "border-bottom": "2px solid #EC4899 !important" 
          },
          ".lexity-word.known": { 
              "background-color": "transparent !important",
              "border-bottom": "none !important",
              "color": "inherit !important"
          },
          ".para-translate-btn": {
              "position": "absolute !important",
              "right": "0px !important", // Move to the extreme edge of the padded paragraph
              "top": "0px !important",
              "width": "32px !important", // Fixed width
              "height": "32px !important", // Fixed height
              "border-radius": "8px !important",
              "background": (t === 'light' ? 'rgba(99, 102, 241, 0.08)' : 'rgba(99, 102, 241, 0.15)') + " !important",
              "border": "1px solid " + (t === 'light' ? 'rgba(99, 102, 241, 0.15)' : 'rgba(99, 102, 241, 0.25)') + " !important",
              "color": "#6366F1 !important", 
              "display": "flex !important", // Use flex for perfect centering
              "align-items": "center !important",
              "justify-content": "center !important",
              "cursor": "pointer !important",
              "font-size": "14px !important", // Slightly smaller font
              "font-weight": "bold !important",
              "user-select": "none !important",
              "-webkit-user-select": "none !important",
              "transition": "all 0.15s ease-in-out !important",
              "z-index": "10 !important"
          },
          ".para-translate-btn span": {
              "display": "block !important",
              "line-height": "1 !important"
          },
          ".para-translate-btn:active": {
              "background": "#6366F1 !important",
              "color": "#ffffff !important",
              "transform": "scale(0.9) !important"
          },
          "::selection": {
              "background-color": "rgba(99, 102, 241, 0.3) !important",
              "text-decoration": "underline !important",
              "text-decoration-color": "#6366F1 !important",
              "color": "inherit !important"
          }
      });
    }

    async function loadBook(config) {
      try {
        const cfg = config || {};
        const url = cfg.url;
        const initialCfi = cfg.initialCfi || "";
        const themeColors = cfg.theme || null;
        const themeName = cfg.themeName || 'light';
        const fontSize = typeof cfg.fontSize === 'number' ? cfg.fontSize : 100;
        const initialVocab = cfg.vocabMap ?? null;

        window.setReaderVisible(false);

        if (themeColors && themeColors.bg) {
          document.body.style.backgroundColor = themeColors.bg;
          document.documentElement.style.backgroundColor = themeColors.bg;
        }

        if (initialVocab) {
          if (typeof initialVocab === "string") {
            try {
              window.vocabMap = JSON.parse(initialVocab);
            } catch (e) {
              console.warn("BookReader JS: Failed to parse initial vocab, using empty map", e);
              window.vocabMap = {};
            }
          } else {
            window.vocabMap = initialVocab;
          }
        }
        console.log("BookReader JS: Attempting to load EPUB from: " + url);
        console.log("BookReader JS: Received initialCfi: " + initialCfi);
        
        await new Promise(r => setTimeout(r, 100));

        book = ePub(url);
        
        await book.ready;

        book.opened.then(() => {
          console.log("BookReader JS: EPUB opened successfully");
        }).catch(err => {
          console.error("BookReader JS: Error opening EPUB: ", err);
        });

        rendition = book.renderTo("viewer", { 
          width: "100%", 
          height: "100%", 
          flow: "paginated", 
          manager: "continuous" 
        });

        if (!rendition.settings.contents) {
            rendition.settings.contents = {};
        }
        rendition.settings.contents.allowScriptedContent = true;
        
        const throttledReportProgress = throttle((resumeCfi, pct) => {
          const sendProgress = () => callFlutter('onProgress', resumeCfi, pct);
          if (typeof requestIdleCallback === 'function') {
            requestIdleCallback(sendProgress, { timeout: 500 });
          } else {
            setTimeout(sendProgress, 0);
          }
        }, 1000);

        rendition.on("relocated", (location) => {
          if (location && location.start) {
            const startCfi = location.start.cfi;
            const endCfi = location.end && location.end.cfi ? location.end.cfi : null;
            const resumeCfi = endCfi && endCfi !== startCfi ? endCfi : startCfi;
            const progressCfi = startCfi || resumeCfi;
            let pct = 0;
            if (book && book.locations && typeof book.locations.percentageFromCfi === 'function') {
              const raw = book.locations.percentageFromCfi(progressCfi);
              if (typeof raw === 'number' && isFinite(raw)) {
                pct = Math.round(raw * 100);
              }
            }
            if (pct === 0) {
              pct = (location.end && location.end.percentage)
                ? Math.round(location.end.percentage * 100)
                : (location.start.percentage ? Math.round(location.start.percentage * 100) : 0);
            }
            if (pct < 0) pct = 0;
            if (pct > 100) pct = 100;
            throttledReportProgress(resumeCfi, pct);
          }
        });

        rendition.hooks.content.register((contents) => {
          const win = contents.window;
          const doc = contents.document;

          const walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT);
          let node;
          const nodes =[];
          while (node = walker.nextNode()) nodes.push(node);

          nodes.forEach(textNode => {
              if (textNode.parentNode && textNode.parentNode.nodeName.toLowerCase() === 'span' && textNode.parentNode.classList.contains('lexity-word')) return;
              if (textNode.parentNode && (textNode.parentNode.nodeName.toLowerCase() === 'script' || textNode.parentNode.nodeName.toLowerCase() === 'style')) return;
              if (textNode.nodeValue.trim().length === 0) return;

              const regex = /([\\p{L}\\p{M}]+)/gu;
              if (regex.test(textNode.nodeValue)) {
                  const span = doc.createElement('span');
                  span.className = 'lexity-word-wrapper';
                  
                  // Wrap each word match in a span with appropriate status
                  span.innerHTML = textNode.nodeValue.replace(regex, (match) => {
                      const normalizedWord = match.toLowerCase();
                      // Use the global cache that was pushed from Dart on startup
                      const status = (window.vocabMap[normalizedWord] || 'unknown').toLowerCase();
                      return `<span class="lexity-word \${status}" data-word="\${normalizedWord}">\${match}</span>`;
                  });
                  textNode.parentNode.replaceChild(span, textNode);
              }
          });

          doc.addEventListener('click', (e) => {
              const span = e.target.closest('.lexity-word');
              if (span) {
                  e.preventDefault();
                  e.stopPropagation();
                  const rect = span.getBoundingClientRect();
                  const word = span.getAttribute('data-word');
                  let contextText = span.parentElement.innerText;
                  if (!contextText || contextText.length < 10) contextText = word; 
                  callFlutter('onWordTap', word, rect.left, rect.top, contextText);
              } else {
                  callFlutter('onBackgroundTap');
              }
          });
          callFlutter('onChapterReady');
          
          const paragraphs = doc.querySelectorAll('p');
          paragraphs.forEach((p) => {
            // Only add buttons to substantial text blocks
            if (p.textContent.trim().length < 15) return; // Lowered threshold slightly
            if (p.querySelector('.para-translate-btn')) return;
            
            const btn = doc.createElement('div');
            btn.className = 'para-translate-btn';
            
            // Use a span wrapper to ensure character centering
            const btnText = doc.createElement('span');
            btnText.innerText = '文';
            btn.appendChild(btnText);
            
            btn.onclick = (e) => {
              e.preventDefault();
              e.stopPropagation();
              callFlutter('onParagraphTranslate', p.innerText);
            };
            p.appendChild(btn);
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
                  callFlutter('onTextSelected', text, contextText);
              } else if (text.length === 0) {
                  window.lastReportedText = "";
              }
          }

          doc.addEventListener('touchend', () => {
              setTimeout(() => checkAndReportSelection(win), 150);
          });

          if (window.currentTheme) {
            applyThemeToContents(contents);
          }
        });

        window.applyTheme = function(c, f, t) {
            if (!rendition) return;
            try {
                window.currentTheme = c;
                window.currentThemeName = t;
                window.currentFontSize = f;
                rendition.themes.fontSize(f + "%");
                rendition.themes.register(t, {
                    "body": { 
                        "background": c.bg + " !important", 
                        "color": c.fg + " !important"
                    },
                    "p, span, div, h1, h2, h3, h4, h5, h6, a, li, ul, ol, td, th": { "color": c.fg + " !important", "background": "transparent !important" },
                    "::selection": { "background": "rgba(99, 102, 241, 0.3) !important", "text-decoration": "underline !important" }
                });
                rendition.themes.select(t);
                
                rendition.getContents().forEach(contents => {
                    if (contents && contents.document) applyThemeToContents(contents);
                });
            } catch (e) {
                console.error("Style update error:", e);
            }
        };

        let touchStartX = 0;
        rendition.on("touchstart", (e) => { 
          touchStartX = e.changedTouches[0].screenX; 
        });
        
        rendition.on("touchend", (e) => {
          const dx = touchStartX - e.changedTouches[0].screenX;
          if (Math.abs(dx) > 50) {
            if (dx > 0) rendition.next();
            else rendition.prev();
          } 
        });

        if (themeColors) {
          window.applyTheme(themeColors, fontSize, themeName);
        }
        
        await new Promise((resolve) => {
          const target = initialCfi && initialCfi.length > 0 ? initialCfi : undefined;
          rendition.display(target).then(() => {
            console.log("BookReader JS: rendition.display() promise resolved");
            resolve();
          });
        });
        
        await new Promise(r => setTimeout(r, 120));
        
        // Handle locations - wait for port handshake first if available
        if (window.portReady) {
          console.log("BookReader JS: Port ready, waiting for locations via port...");
        } else {
          console.log("BookReader JS: Port not ready yet, will generate if needed...");
        }
        
        window.setReaderVisible(true);
        console.log("BookReader JS: Display completed, calling onReady");
        callFlutter('onReady');

        const flattenToc = (items, level = 0) => {
          return items.reduce((acc, item) => {
            acc.push({ label: item.label, href: item.href, level: level });
            if (item.subitems && item.subitems.length > 0) {
              acc.push(...flattenToc(item.subitems, level + 1));
            }
            return acc;
          }, []);
        };
        const toc = flattenToc(book.navigation.toc);
        callFlutter('onToc', toc);

      } catch (error) {
        console.error("EPUB Loading Error: " + error.message);
      }
    }
  </script>
</body>
</html>
""";
