# DATABASE

**Parent:** `../AGENTS.md` — See root for full context.

## OVERVIEW
SQLite via sqflite. Single 923-line `AppDatabase` class. WAL mode enabled.

## SCHEMA (all in `app_database.dart`)
| Table | Key | Notes |
|-------|-----|-------|
| `users` | id | Auth data |
| `books` | id | Epub metadata + CFI progress |
| `journals` | id | AI-analyzed entries |
| `srs_items` | id | Spaced repetition cards |
| `vocabularies` | word (lowercase) | Per-language vocab tracking |
| `sync_queue` | id | Offline mutation queue |
| `learning_modules` | id | Path modules |
| `analytics_cache` | id | Cached AI analytics |
| `due_srs_items` | — | View (query on srs_items) |

## TABLES CREATED IN MIGRATIONS
| Version | Tables Added |
|---------|--------------|
| 2 | `analytics_cache`, `learning_modules` |
| 3+ | See `onUpgrade()` in app_database.dart |

## SYNC ARCHITECTURE
- Offline mutations queued in `sync_queue` with `retry_count`
- Bulk sync: batches of 50, max 3 concurrent
- Delta sync: fetches changes since `last_sync_timestamp`
- Isolate used in `_processBulkBatch()` and `_processChanges()` to offload JSON work

## PROVIDER
```dart
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
```

## NOTES
- `AppDatabase` is a singleton (`static Database? _database`)
- 7 tables with change notification via `StreamController`
- `sync_queue` table: stores `entity_type`, `action`, `payload_json`, `retry_count`
- Consider splitting `app_database.dart` — 923 lines is too large
