# SERVICES

**Parent:** `../AGENTS.md` — See root for full context.

## OVERVIEW
16 service files. Business logic layer. Services are injected via Riverpod providers.

## FILES
| Service | Lines | Purpose |
|---------|-------|---------|
| `ai_service.dart` | 500 | Gemini API calls |
| `sync_service.dart` | 373 | Offline queue management |
| `book_service.dart` | 518 | Epub download + storage |
| `journal_service.dart` | 361 | Journal CRUD + AI analysis |
| `srs_service.dart` | 200+ | Spaced repetition logic |
| `vocabulary_service.dart` | 200+ | Vocab tracking + sync |
| `auth_service.dart` | 150+ | JWT token management |
| `analytics_service.dart` | 130+ | AI-powered insights |
| `user_service.dart` | 150+ | Profile management |
| `learning_path_service.dart` | 150+ | Module progression |
| `hydration_service.dart` | ~50 | Initial data load |
| `connectivity_service.dart` | ~40 | Network monitoring |
| `logger_service.dart` | ~80 | File-based logging |
| `listening_service.dart` | ~30 | Audio content |
| `reading_service.dart` | ~30 | Reading content |
| `token_service.dart` | ~70 | Token storage |

## PROVIDER PATTERN
```dart
final serviceNameProvider = Provider<ServiceName>((ref) {
  final dep1 = ref.watch(dep1Provider);
  final dep2 = ref.watch(dep2Provider);
  return ServiceName(dep1, dep2);
});
```

## NOTES
- Services are stateless — hold dependencies, expose async methods
- `SyncService` uses `Isolate.run()` for heavy JSON processing
- `AiService` wraps Gemini API calls with error handling
- `AuthService` manages JWT refresh, logout, and disk persistence
