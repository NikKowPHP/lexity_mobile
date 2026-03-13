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
    #viewer { width: 100%; height: 100%; position: absolute; top: 0; left: 0; right: 0; bottom: 0; }
    mark.known-word { background-color: rgba(99, 102, 241, 0.3) !important; border-bottom: 2px dotted #6366F1 !important; color: inherit !important; }
  </style>
</head>
<body>
  <div id="viewer"></div>
  <script>
    let book;
    let rendition;
    window.vocabMap = {}; // NEW: Global cache in JS
    window.lastReportedText = "";

    window.applyVocabStyles = function(vocabMapJson) {
      if (!rendition) return;
      window.vocabMap = JSON.parse(vocabMapJson); // NEW: Update global cache
      const vocabMap = window.vocabMap;
      rendition.getContents().forEach(content => {
          const spans = content.document.querySelectorAll('.lexity-word');
          spans.forEach(span => {
              const dataWord = span.getAttribute('data-word');
              if (!dataWord) return;
              const word = dataWord.toLowerCase();
              // Normalize the status to lowercase to match CSS selectors
              const status = (vocabMap[word] || 'unknown').toLowerCase();
              
              // Only update if the class has actually changed to prevent flickering
              const newClassName = 'lexity-word ' + status;
              if (span.className !== newClassName) {
                  span.className = newClassName;
              }
          });
      });
    };

    window.getVisibleUnknownWords = function() {
      if (!rendition) return [];
      const visible =[];
      rendition.getContents().forEach(content => {
          const win = content.window;
          const spans = content.document.querySelectorAll('.lexity-word.unknown');
          spans.forEach(span => {
              const rect = span.getBoundingClientRect();
              if (rect.top >= 0 && rect.left >= 0 && Math.floor(rect.bottom) <= win.innerHeight && Math.floor(rect.right) <= win.innerWidth) {
                  visible.push(span.getAttribute('data-word').toLowerCase());
              }
          });
      });
      return Array.from(new Set(visible));
    };

    async function loadBook(url, initialCfi) {
      try {
        console.log("BookReader JS: Starting ePub initialization");
        book = ePub(url);
        
        await book.opened;

        rendition = book.renderTo("viewer", { 
          width: "100%", 
          height: "100%", 
          flow: "paginated", 
          manager: "continuous" 
        });

        // Force epub.js to allow scripts within its internal iframes.
        if (!rendition.settings.contents) {
            rendition.settings.contents = {};
        }
        rendition.settings.contents.allowScriptedContent = true;
        
        rendition.on("relocated", (location) => {
          window.requestAnimationFrame(() => {
            const currentLocation = rendition.currentLocation();
            if (currentLocation && currentLocation.start) {
              const pct = currentLocation.start.percentage ? Math.round(currentLocation.start.percentage * 100) : 0;
              window.flutter_inappwebview.callHandler('onProgress', currentLocation.start.cfi, pct);
            }
          });
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
                  window.flutter_inappwebview.callHandler('onWordTap', word, rect.left, rect.top, contextText);
              } else {
                  window.flutter_inappwebview.callHandler('onBackgroundTap');
              }
          });
          window.flutter_inappwebview.callHandler('onChapterReady');
          
          const paragraphs = doc.querySelectorAll('p');
          paragraphs.forEach((p) => {
            // Only add buttons to substantial text blocks
            if (p.textContent.trim().length < 25) return;
            if (p.querySelector('.para-translate-btn')) return;
            
            const btn = doc.createElement('div');
            btn.className = 'para-translate-btn';
            // Use a spans for the icon text to ensure it's centered
            btn.innerHTML = '<span>文</span>'; 
            
            btn.onclick = (e) => {
              e.preventDefault();
              e.stopPropagation();
              window.flutter_inappwebview.callHandler('onParagraphTranslate', p.innerText);
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
                  window.flutter_inappwebview.callHandler('onTextSelected', text, contextText);
              } else if (text.length === 0) {
                  window.lastReportedText = "";
              }
          }

          doc.addEventListener('selectionchange', () => {
              clearTimeout(window.selectionTimeout);
              window.selectionTimeout = setTimeout(() => checkAndReportSelection(win), 800);
          });

          doc.addEventListener('touchend', () => {
              setTimeout(() => checkAndReportSelection(win), 150);
          });
        });

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

        let hasAppliedOffset = false;
        rendition.on("rendered", (section) => {
          if (initialCfi && !hasAppliedOffset) {
            hasAppliedOffset = true;
            // Wait for layout to settle before jumping a page forward
            setTimeout(() => {
              console.log("BookReader JS: Initial render complete, applying +1 page offset");
              rendition.next();
            }, 250);
          }
        });

        await rendition.display(initialCfi || undefined);

        window.flutter_inappwebview.callHandler('onReady');
        
        await book.ready;
        await book.locations.generate(1600);

        const loc = rendition.currentLocation();
        if (loc && loc.start) {
            const pct = loc.start.percentage ? Math.round(loc.start.percentage * 100) : 0;
            window.flutter_inappwebview.callHandler('onProgress', loc.start.cfi, pct);
        }

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
        window.flutter_inappwebview.callHandler('onToc', toc);

      } catch (error) {
        console.error("EPUB Loading Error: " + error.message);
      }
    }
  </script>
</body>
</html>
""";
