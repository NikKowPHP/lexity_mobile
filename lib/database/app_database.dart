import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'daos/user_dao.dart';
import 'daos/book_dao.dart';
import 'daos/journal_dao.dart';
import 'daos/srs_dao.dart';
import 'daos/vocabulary_dao.dart';

class AppDatabase {
  static Database? _database;
  static const String _dbName = 'lexity.db';
  static const int _dbVersion = 5;

  final Map<String, StreamController<List<Map<String, dynamic>>>> _controllers =
      {};

  // DAOs
  late final UserDao userDao;
  late final BookDao bookDao;
  late final JournalDao journalDao;
  late final SrsDao srsDao;
  late final VocabularyDao vocabularyDao;

  AppDatabase() {
    // Initialize DAOs
    userDao = UserDao(this);
    bookDao = BookDao(this);
    journalDao = JournalDao(this);
    srsDao = SrsDao(this);
    vocabularyDao = VocabularyDao(this);
  }

  StreamController<List<Map<String, dynamic>>> getController(String key) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] =
          StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    return _controllers[key]!;
  }

  void notify(String key) async {
    final db = await database;
    final data = await db.query(_tableForKey(key));
    getController(key).add(data);
  }

  String _tableForKey(String key) {
    switch (key) {
      case 'users':
        return 'users';
      case 'books':
        return 'books';
      case 'journals':
        return 'journals';
      case 'srs_items':
        return 'srs_items';
      case 'vocabularies':
        return 'vocabularies';
      case 'sync_queue':
        return 'sync_queue';
      case 'due_srs_items':
        return 'srs_items';
      default:
        return key;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onOpen: (db) async {
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.rawQuery('PRAGMA synchronous = NORMAL');
        await db.rawQuery('PRAGMA busy_timeout = 5000');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS analytics_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target_language TEXT NOT NULL,
            data_json TEXT NOT NULL,
            fetched_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS learning_modules (
            id TEXT PRIMARY KEY,
            language TEXT NOT NULL,
            title TEXT NOT NULL,
            status TEXT NOT NULL,
            target_concept_tag TEXT,
            micro_lesson TEXT,
            activities_json TEXT,
            completed_at INTEGER,
            last_synced_at INTEGER
          )
        ''');
      }

      if (oldVersion < 3) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            action TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            retry_count INTEGER DEFAULT 0
          )
        ''');
      }

      if (oldVersion < 5) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_metadata (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      }

      if (oldVersion < 6) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS downloaded_models (
            language_code TEXT PRIMARY KEY,
            model_type TEXT NOT NULL,
            downloaded_at INTEGER NOT NULL
          )
        ''');
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE translation_cache (
        cache_key TEXT PRIMARY KEY,
        data_json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        native_language TEXT,
        default_target_language TEXT NOT NULL,
        writing_style TEXT,
        writing_purpose TEXT,
        self_assessed_level TEXT,
        subscription_tier TEXT DEFAULT 'FREE',
        subscription_status TEXT,
        subscription_period_end INTEGER,
        language_profiles_json TEXT DEFAULT '[]',
        goals_json TEXT,
        current_streak INTEGER DEFAULT 0,
        longest_streak INTEGER DEFAULT 0,
        onboarding_completed INTEGER DEFAULT 0,
        srs_count INTEGER DEFAULT 0,
        last_synced_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        target_language TEXT NOT NULL,
        storage_path TEXT NOT NULL,
        cover_image_url TEXT,
        current_cfi TEXT,
        progress_pct REAL DEFAULT 0.0,
        created_at INTEGER NOT NULL,
        signed_url TEXT,
        locations TEXT,
        last_synced_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE journals (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        audio_url TEXT,
        is_pending_analysis INTEGER DEFAULT 0,
        analysis_json TEXT,
        last_synced_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE srs_items (
        id TEXT PRIMARY KEY,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        context TEXT,
        type TEXT DEFAULT 'TRANSLATION',
        next_review_date INTEGER NOT NULL,
        last_synced_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE vocabularies (
        word TEXT PRIMARY KEY,
        status TEXT DEFAULT 'new',
        language TEXT NOT NULL,
        last_synced_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        action TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE analytics_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_language TEXT NOT NULL,
        data_json TEXT NOT NULL,
        fetched_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE learning_modules (
        id TEXT PRIMARY KEY,
        language TEXT NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        target_concept_tag TEXT,
        micro_lesson TEXT,
        activities_json TEXT,
        completed_at INTEGER,
        last_synced_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE downloaded_models (
        language_code TEXT PRIMARY KEY,
        model_type TEXT NOT NULL,
        downloaded_at INTEGER NOT NULL
      )
    ''');
  }

  // Users - delegates to UserDao for backward compatibility
  Future<int> insertUser(Map<String, dynamic> user) => userDao.insertUser(user);

  Future<Map<String, dynamic>?> getUserById(String id) =>
      userDao.getUserById(id);

  Future<List<Map<String, dynamic>>> getAllUsers() => userDao.getAllUsers();

  Stream<List<Map<String, dynamic>>> watchAllUsers() => userDao.watchAllUsers();

  // Books - delegates to BookDao for backward compatibility
  Future<int> insertBook(Map<String, dynamic> book) => bookDao.insertBook(book);

  Future<Map<String, dynamic>?> getBookById(String id) =>
      bookDao.getBookById(id);

  Future<List<Map<String, dynamic>>> getAllBooks() => bookDao.getAllBooks();

  Stream<List<Map<String, dynamic>>> watchAllBooks() => bookDao.watchAllBooks();

  Future<int> updateBookProgress(String id, String cfi, double progress) =>
      bookDao.updateBookProgress(id, cfi, progress);

  Future<int> deleteBook(String id) => bookDao.deleteBook(id);

  Future<void> insertBooksBatch(List<Map<String, dynamic>> items) =>
      bookDao.insertBooksBatch(items);

  // Journals - delegates to JournalDao for backward compatibility
  Future<int> insertJournal(Map<String, dynamic> journal) =>
      journalDao.insertJournal(journal);

  Future<Map<String, dynamic>?> getJournalById(String id) =>
      journalDao.getJournalById(id);

  Future<List<Map<String, dynamic>>> getAllJournals() =>
      journalDao.getAllJournals();

  Stream<List<Map<String, dynamic>>> watchAllJournals() =>
      journalDao.watchAllJournals();

  Future<void> insertJournalsBatch(List<Map<String, dynamic>> items) =>
      journalDao.insertJournalsBatch(items);

  // SRS Items - delegates to SrsDao for backward compatibility
  Future<int> insertSrsItem(Map<String, dynamic> item) =>
      srsDao.insertSrsItem(item);

  Future<List<Map<String, dynamic>>> getAllSrsItems() =>
      srsDao.getAllSrsItems();

  Stream<List<Map<String, dynamic>>> watchAllSrsItems() =>
      srsDao.watchAllSrsItems();

  Future<List<Map<String, dynamic>>> getDueSrsItems() =>
      srsDao.getDueSrsItems();

  Stream<List<Map<String, dynamic>>> watchDueSrsItems() =>
      srsDao.watchDueSrsItems();

  Future<int> updateSrsItemReviewDate(String id, DateTime nextReview) =>
      srsDao.updateSrsItemReviewDate(id, nextReview);

  Future<void> insertSrsBatch(List<Map<String, dynamic>> items) =>
      srsDao.insertSrsBatch(items);

  // Vocabularies - delegates to VocabularyDao for backward compatibility
  Future<int> insertVocabulary(Map<String, dynamic> vocab) =>
      vocabularyDao.insertVocabulary(vocab);

  Future<List<Map<String, dynamic>>> getAllVocabularies() =>
      vocabularyDao.getAllVocabularies();

  Future<List<Map<String, dynamic>>> getVocabulariesByLanguage(
    String language,
  ) => vocabularyDao.getVocabulariesByLanguage(language);

  Stream<List<Map<String, dynamic>>> watchAllVocabularies() =>
      vocabularyDao.watchAllVocabularies();

  Future<int> deleteVocabulary(String word) =>
      vocabularyDao.deleteVocabulary(word);

  Future<void> insertVocabularyBatch(List<Map<String, dynamic>> items) =>
      vocabularyDao.insertVocabularyBatch(items);

  Future<List<String>> getVocabularyLanguages() =>
      vocabularyDao.getVocabularyLanguages();

  // Sync Queue operations (remain inline as they are cross-cutting)
  Future<void> compactSyncQueue() async {
    final db = await database;
    await db.transaction((txn) async {
      // For book progress updates, keep only the most recent entry per book_id
      await txn.execute('''
        DELETE FROM sync_queue
        WHERE id NOT IN (
          SELECT MAX(id)
          FROM sync_queue
          WHERE entity_type = 'book' AND action = 'update_progress'
          GROUP BY entity_id
        )
        AND entity_type = 'book' AND action = 'update_progress'
      ''');

      // For vocabulary updates, keep only the most recent entry per word
      await txn.execute('''
        DELETE FROM sync_queue
        WHERE id NOT IN (
          SELECT MAX(id)
          FROM sync_queue
          WHERE entity_type = 'vocabulary' AND action = 'update'
          GROUP BY entity_id
        )
        AND entity_type = 'vocabulary' AND action = 'update'
      ''');
    });
    notify('sync_queue');
  }

  // Sync Queue
  Future<int> enqueueMutation(Map<String, dynamic> mutation) async {
    final db = await database;

    if (mutation['entity_type'] == 'book' &&
        mutation['action'] == 'update_progress') {
      await db.delete(
        'sync_queue',
        where: 'entity_type = ? AND action = ? AND entity_id = ?',
        whereArgs: ['book', 'update_progress', mutation['entity_id']],
      );
    }

    final result = await db.insert('sync_queue', {
      ...mutation,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    notify('sync_queue');
    return result;
  }

  Future<List<Map<String, dynamic>>> getPendingMutations({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    return await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
      limit: limit,
      offset: offset,
    );
  }

  Stream<List<Map<String, dynamic>>> watchPendingMutations() async* {
    yield await getPendingMutations();
    yield* getController('sync_queue').stream;
  }

  Future<int> getPendingMutationsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> removeMutation(int id) async {
    final db = await database;
    final result = await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    notify('sync_queue');
    return result;
  }

  Future<int> removeMutations(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.delete(
      'sync_queue',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    notify('sync_queue');
    return result;
  }

  Future<int> incrementRetryCount(int id) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue');
    notify('sync_queue');
  }

  // Analytics Cache
  Future<void> cacheAnalytics(
    String targetLanguage,
    Map<String, dynamic> data,
  ) async {
    try {
      final db = await database;
      await db.insert('analytics_cache', {
        'target_language': targetLanguage,
        'data_json': jsonEncode(data),
        'fetched_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      // Table doesn't exist yet
    }
  }

  Future<Map<String, dynamic>?> getCachedAnalytics(
    String targetLanguage,
  ) async {
    try {
      final db = await database;
      final results = await db.query(
        'analytics_cache',
        where: 'target_language = ?',
        whereArgs: [targetLanguage],
        orderBy: 'fetched_at DESC',
        limit: 1,
      );
      if (results.isEmpty) return null;
      return jsonDecode(results.first['data_json'] as String);
    } catch (e) {
      return null;
    }
  }

  // Translation Cache
  Future<void> cacheTranslation(String key, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('translation_cache', {
      'cache_key': key,
      'data_json': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getCachedTranslation(String key) async {
    final db = await database;
    final results = await db.query(
      'translation_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data_json'] as String);
  }

  // Learning Modules Cache
  Future<void> cacheLearningModules(
    String language,
    List<Map<String, dynamic>> modules,
  ) async {
    try {
      final db = await database;
      await db.delete(
        'learning_modules',
        where: 'language = ?',
        whereArgs: [language],
      );
      for (final module in modules) {
        await db.insert('learning_modules', {
          'id': module['id'],
          'language': language,
          'title': module['title'] ?? '',
          'status': module['status'] ?? 'PENDING',
          'target_concept_tag': module['targetConceptTag'] ?? '',
          'micro_lesson': module['microLesson'] ?? '',
          'activities_json': jsonEncode(module['activities'] ?? {}),
          'completed_at': module['completedAt'] != null
              ? DateTime.parse(module['completedAt']).millisecondsSinceEpoch
              : null,
          'last_synced_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      // Table doesn't exist yet, ignore
    }
  }

  Future<void> insertLearningModule(Map<String, dynamic> module) async {
    final db = await database;
    await db.insert(
      'learning_modules',
      module,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedLearningModules(
    String language,
  ) async {
    try {
      final db = await database;
      final results = await db.query(
        'learning_modules',
        where: 'language = ?',
        whereArgs: [language],
      );
      return results
          .map(
            (row) => {
              'id': row['id'],
              'title': row['title'],
              'status': row['status'],
              'targetConceptTag': row['target_concept_tag'],
              'microLesson': row['micro_lesson'],
              'activities': jsonDecode(
                row['activities_json'] as String? ?? '{}',
              ),
              'completedAt': row['completed_at'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      row['completed_at'] as int,
                    ).toIso8601String()
                  : null,
            },
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Sync Metadata
  Future<String?> getLastSyncTimestamp() async {
    final db = await database;
    final results = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: ['last_synced_at'],
    );
    return results.isNotEmpty ? results.first['value'] as String? : null;
  }

  Future<void> updateLastSyncTimestamp(String timestamp) async {
    final db = await database;
    await db.insert('sync_metadata', {
      'key': 'last_synced_at',
      'value': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Downloaded Models Management
  Future<void> saveDownloadedModel(
    String languageCode,
    String modelType,
  ) async {
    final db = await database;
    await db.insert('downloaded_models', {
      'language_code': languageCode,
      'model_type': modelType,
      'downloaded_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<String>> getDownloadedModels() async {
    final db = await database;
    final results = await db.query('downloaded_models');
    return results.map((row) => row['language_code'] as String).toList();
  }

  Future<bool> isModelDownloaded(String languageCode) async {
    final db = await database;
    final results = await db.query(
      'downloaded_models',
      where: 'language_code = ?',
      whereArgs: [languageCode],
    );
    return results.isNotEmpty;
  }

  Future<void> removeDownloadedModel(String languageCode) async {
    final db = await database;
    await db.delete(
      'downloaded_models',
      where: 'language_code = ?',
      whereArgs: [languageCode],
    );
  }

  Future<Database> getRawDatabase() async => await database;

  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Clears all user-scoped data from the database.
  /// Should be called on login to ensure a fresh state for the new user.
  Future<void> clearAllUserData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('users');
      await txn.delete('books');
      await txn.delete('journals');
      await txn.delete('srs_items');
      await txn.delete('vocabularies');
      await txn.delete('sync_queue');
      await txn.delete('analytics_cache');
      await txn.delete('learning_modules');
    });
    // Notify all watchers to refresh
    notify('users');
    notify('books');
    notify('journals');
    notify('srs_items');
    notify('vocabularies');
    notify('sync_queue');
  }
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
