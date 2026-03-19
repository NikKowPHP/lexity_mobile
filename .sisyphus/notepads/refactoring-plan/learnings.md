# Refactoring Plan Learnings

## Conventions Discovered

### DAO Pattern
- Each DAO should be a class that takes `Database` in constructor
- Use `conflictAlgorithm: ConflictAlgorithm.replace` for upsert behavior
- Wrap heavy operations in isolates for large datasets
- Expose streams for reactive updates via `_notify()` pattern

### Database Singleton
- `AppDatabase._database` is the singleton instance
- Connection is lazy-loaded via `get database` getter
- WAL mode enabled: `PRAGMA journal_mode = WAL`

### Change Notification
- `Map<String, StreamController<List<Map<String, dynamic>>>> _controllers`
- `_notify('table_name')` triggers stream updates
- Pattern: `watchAllUsers()` yields current then streams

### Migration Strategy
- Version-based migrations in `_onUpgrade()`
- Tables created with `CREATE TABLE IF NOT EXISTS`
- Catch exceptions to handle "table already exists" gracefully
