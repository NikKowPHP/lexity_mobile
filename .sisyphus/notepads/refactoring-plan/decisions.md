# Refactoring Plan Decisions

## Architecture Decisions

### Task 1.1: AppDatabase Split
**Decision:** Keep `AppDatabase` as the connection manager + migrations only
- Create separate DAO classes for each table
- Each DAO receives `Database` instance via constructor
- `AppDatabase` exposes DAOs via getters
- Maintain backward compatibility during transition

### DAO Structure
```dart
class BookDao {
  final Database _db;
  BookDao(this._db);
  
  Future<int> insert(Book book) {...}
  Future<List<Book>> getAll() {...}
  Stream<List<Book>> watchAll() async* {...}
}
```

### Not Implementing (scope reduction)
- Sync queue compaction logic stays in AppDatabase (cross-entity operations)
- Analytics cache stays in AppDatabase (simple key-value)
- Translation cache stays in AppDatabase (simple key-value)
- Learning modules stays in AppDatabase (small table)
- Downloaded models stays in AppDatabase (small table)
- SRS due items query stays in AppDatabase (complex aggregation)
