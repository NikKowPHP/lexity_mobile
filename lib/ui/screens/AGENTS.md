# UI SCREENS

**Parent:** `../AGENTS.md` — See root for full context.

## OVERVIEW
21 screen files, ~3000+ lines total. Mix of consumer widgets and platform integrations.

## HOTSPOTS
| File | Lines | Issue |
|------|-------|-------|
| `book_reader_screen.dart` | **1497** | Needs refactor — WebView + audio + progress + theme |
| `profile_screen.dart` | 699 | Analytics charts + settings |
| `book_reader_html.dart` | 575 | HTML renderer for epub |
| `translator_screen.dart` | 502 | AI + camera + bubble mode |
| `reading_screen.dart` | 372 | Reading exercises |
| `listening_screen.dart` | 366 | Audio player + transcript |

## SCREEN ENTRY POINTS
```
All screens imported in lib/router/router.dart:
- LoginScreen → /login
- PathScreen → /path (main tab)
- StudyScreen → /study
- LibraryScreen → /library
- TranslatorScreen → /translator (+ /bubble-translator standalone)
- MoreScreen → /more
- ProgressScreen → /progress (hidden)
- ProfileScreen → /profile (hidden)
- BookReaderScreen → /library/book/:id
- VocabularyScreen → /vocabulary (standalone)
- SRSItemsScreen → /srs-items (standalone)
- JournalEditorScreen → /journal/new
- JournalDetailScreen → /journal/:id
```

## PATTERNS
- Screens use `ConsumerStatefulWidget` (Riverpod state)
- Platform-specific: `book_reader_screen.dart` uses `InAppWebView`, `kIsWeb`, `Platform.isWindows`
- Large screens delegate to sub-widgets in `../widgets/`

## NOTES
- 2 hidden routes (Progress, Profile) accessible via More tab
- Bubble translator is standalone outside StatefulShellRoute (no bottom nav)
- `book_reader_screen.dart` has `with WidgetsBindingObserver` for audio interruption
