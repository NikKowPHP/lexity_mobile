# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-19
**Commit:** 0e38054
**Branch:** main

## OVERVIEW
Language learning mobile app (Flutter/Dart) with offline-first architecture, multi-platform (Android/iOS/web/Windows/Linux/macOS).

## STRUCTURE
```
lexity_mobile/
├── lib/                    # PRIMARY source root
│   ├── main.dart          # Entry point
│   ├── database/           # SQLite (sqflite) — 923-line monolith
│   ├── data/              # Repositories + datasources
│   ├── models/            # Data classes (11 files)
│   ├── network/           # Dio API client
│   ├── providers/         # Riverpod state management
│   ├── router/            # GoRouter config (6 branches)
│   ├── services/          # Business logic (16 files)
│   ├── theme/             # Liquid UI theming
│   ├── ui/                # Screens + widgets
│   └── utils/             # Constants
├── src/app/api/           # Minimal Next.js leftover (ignore)
├── test/                  # Flutter tests (4 active files)
├── android/               # Gradle 8.14, AGP 8.11.1
├── ios/                   # Xcode via Flutter toolchain
└── pubspec.yaml           # SDK ^3.10.8
```

## STACK
| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.x, Dart SDK ^3.10.8 |
| State | Riverpod (flutter_riverpod) |
| Routing | go_router 17.x |
| Database | sqflite 2.4.1 (SQLite, WAL mode) |
| Network | Dio 5.4.0 + http |
| Auth | JWT via custom auth service |
| Sync | Offline-first with queued mutations |
| AI | Gemini API (ai_service.dart) |

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add screen | `lib/ui/screens/` | 21 screens, largest files |
| State logic | `lib/providers/` | 14 Riverpod providers |
| Business logic | `lib/services/` | 16 service files |
| Database schema | `lib/database/app_database.dart` | 923 lines, all tables here |
| Auth flow | `lib/providers/auth_provider.dart` | 7826 bytes |
| Navigation | `lib/router/router.dart` | 6-tab shell, 2 hidden tabs |
| Sync logic | `lib/services/sync_service.dart` | Isolate-based batching |

## CONVENTIONS (THIS PROJECT)
- **Query params over path params** — StudyMaterial uses `?content=`, `?moduleId=` in URLs
- **Hidden nav branches** — Progress/Profile accessed via "More" tab (no bottom nav icons)
- **Riverpod DI** — Providers inject other providers, services injected via `Provider<Service>`
- **Platform-specific init in main()** — Windows WebView2 initialization mixed into shared entry
- **Database singleton** — `AppDatabase._database` static singleton pattern
- **No feature folders** — Code grouped by type (services/, providers/), not feature
- **Dual source roots** — `lib/` is primary, `src/` is minimal/legacy

## ANTI-PATTERNS (THIS PROJECT)
- **No TODO/FIXME/HACK comments** — Clean codebase
- **No custom lint rules** — Using default flutter_lints only
- **No CI/CD** — No GitHub Actions, no Fastlane, no Makefile
- **Stale widget_test.dart** — Tests non-existent counter widget
- **test.sh has hardcoded API key** — Do not commit production secrets

## CODE MAP
| Symbol | Type | Location | Role |
|--------|------|----------|------|
| `AppDatabase` | class | `database/app_database.dart` | SQLite singleton, 7 tables |
| `SyncService` | class | `services/sync_service.dart` | Offline queue, Isolate batching |
| `AuthProvider` | Notifier | `providers/auth_provider.dart` | JWT auth state |
| `GoRouter` | router | `router/router.dart` | 6 StatefulShell branches |
| `AiService` | class | `services/ai_service.dart` | Gemini API calls |
| `BookReaderScreen` | Widget | `ui/screens/` | 1497 lines — largest file |

## COMMANDS
```bash
flutter run                    # Run app
flutter analyze                # Lint (run after every feature)
flutter test                   # Run tests
flutter test test/book_test.dart  # Run specific test
dart run build_runner build --delete-conflicting-outputs  # Generate mocks
flutter build apk --release    # Build Android
flutter build ios --release    # Build iOS
```

## NOTES
- Build output → `./build/` (not `android/build`)
- Android JVM: 8GB heap, 4GB metaspace
- `lib/database/app_database.dart` is 923 lines — consider splitting
- `lib/ui/screens/book_reader_screen.dart` is 1497 lines — candidate for refactor
- Test mocks generated with `build_runner`, regenerated after mock target changes
