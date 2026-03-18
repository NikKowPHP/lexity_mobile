import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppDatabase {
  static Database? _database;
  static const String _dbName = 'lexity.db';
  static const int _dbVersion = 4;

  final Map<String, StreamController<List<Map<String, dynamic>>>> _controllers =
      {};

  StreamController<List<Map<String, dynamic>>> _getController(String key) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] =
          StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    return _controllers[key]!;
  }

  void _notify(String key) async {
    final db = await database;
    final data = await db.query(_tableForKey(key));
    _getController(key).add(data);
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
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _onCreate(Database db, int version) async {
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
  }

  // Users
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;

    final mappedUser = {
      'id': user['id'],
      'email': user['email'],
      'native_language': user['nativeLanguage'],
      'default_target_language': user['defaultTargetLanguage'],
      'writing_style': user['writingStyle'],
      'writing_purpose': user['writingPurpose'],
      'self_assessed_level': user['selfAssessedLevel'],
      'subscription_tier': user['subscriptionTier'],
      'subscription_status': user['subscriptionStatus'],
      'subscription_period_end': user['subscriptionPeriodEnd'] != null
          ? DateTime.parse(user['subscriptionPeriodEnd']).millisecondsSinceEpoch
          : null,
      'language_profiles_json': user['languageProfiles'] != null
          ? jsonEncode(user['languageProfiles'])
          : '[]',
      'goals_json': user['goals'] != null ? jsonEncode(user['goals']) : null,
      'current_streak': user['currentStreak'] ?? 0,
      'longest_streak': user['longestStreak'] ?? 0,
      'onboarding_completed': user['onboardingCompleted'] == true ? 1 : 0,
      'srs_count': user['srsCount'] ?? 0,
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    };

    final result = await db.insert(
      'users',
      mappedUser,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify('users');
    return result;
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    final db = await database;
    final results = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    final results = await db.query('users');

    return results.map((row) {
      return {
        'id': row['id'],
        'email': row['email'],
        'nativeLanguage': row['native_language'],
        'defaultTargetLanguage': row['default_target_language'],
        'writingStyle': row['writing_style'],
        'writingPurpose': row['writing_purpose'],
        'selfAssessedLevel': row['self_assessed_level'],
        'subscriptionTier': row['subscription_tier'],
        'subscriptionStatus': row['subscription_status'],
        'subscriptionPeriodEnd': row['subscription_period_end'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                row['subscription_period_end'] as int,
              ).toIso8601String()
            : null,
        'languageProfiles': row['language_profiles_json'] != null
            ? jsonDecode(row['language_profiles_json'] as String)
            : [],
        'goals': row['goals_json'] != null
            ? jsonDecode(row['goals_json'] as String)
            : null,
        'currentStreak': row['current_streak'],
        'longestStreak': row['longest_streak'],
        'onboardingCompleted': row['onboarding_completed'] == 1,
        'srsCount': row['srs_count'],
      };
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchAllUsers() async* {
    yield await getAllUsers();
    yield* _getController('users').stream;
  }

  // Books
  Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await database;
    final result = await db.insert(
      'books',
      book,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify('books');
    return result;
  }

  Future<Map<String, dynamic>?> getBookById(String id) async {
    final db = await database;
    final results = await db.query('books', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllBooks() async {
    final db = await database;
    return await db.query('books');
  }

  Stream<List<Map<String, dynamic>>> watchAllBooks() async* {
    yield await getAllBooks();
    yield* _getController('books').stream;
  }

  Future<int> updateBookProgress(String id, String cfi, double progress) async {
    final db = await database;
    final result = await db.update(
      'books',
      {'current_cfi': cfi, 'progress_pct': progress},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify('books');
    return result;
  }

  Future<int> deleteBook(String id) async {
    final db = await database;
    final result = await db.delete('books', where: 'id = ?', whereArgs: [id]);
    _notify('books');
    return result;
  }

  Future<void> insertBooksBatch(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'books',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notify('books');
  }

  // Journals
  Future<int> insertJournal(Map<String, dynamic> journal) async {
    final db = await database;
    final result = await db.insert(
      'journals',
      journal,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify('journals');
    return result;
  }

  Future<Map<String, dynamic>?> getJournalById(String id) async {
    final db = await database;
    final results = await db.query(
      'journals',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllJournals() async {
    final db = await database;
    return await db.query('journals', orderBy: 'created_at DESC');
  }

  Stream<List<Map<String, dynamic>>> watchAllJournals() async* {
    yield await getAllJournals();
    yield* _getController('journals').stream;
  }

  // SRS Items
  Future<int> insertSrsItem(Map<String, dynamic> item) async {
    final db = await database;
    final result = await db.insert(
      'srs_items',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify('srs_items');
    _notifyDueSrsItems();
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllSrsItems() async {
    final db = await database;
    return await db.query('srs_items');
  }

  Stream<List<Map<String, dynamic>>> watchAllSrsItems() async* {
    yield await getAllSrsItems();
    yield* _getController('srs_items').stream;
  }

  Future<List<Map<String, dynamic>>> getDueSrsItems() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.query(
      'srs_items',
      where: 'next_review_date <= ?',
      whereArgs: [now],
    );
  }

  void _notifyDueSrsItems() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = await db.query(
      'srs_items',
      where: 'next_review_date <= ?',
      whereArgs: [now],
    );
    _getController('due_srs_items').add(data);
  }

  Stream<List<Map<String, dynamic>>> watchDueSrsItems() async* {
    yield await getDueSrsItems();
    yield* _getController('due_srs_items').stream;
    yield* Stream.periodic(
      const Duration(minutes: 1),
    ).asyncMap((_) => getDueSrsItems());
  }

  Future<int> updateSrsItemReviewDate(String id, DateTime nextReview) async {
    final db = await database;
    final result = await db.update(
      'srs_items',
      {'next_review_date': nextReview.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify('srs_items');
    _notifyDueSrsItems();
    return result;
  }

  // Vocabularies
  Future<int> insertVocabulary(Map<String, dynamic> vocab) async {
    final db = await database;
    final result = await db.insert(
      'vocabularies',
      vocab,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify('vocabularies');
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllVocabularies() async {
    final db = await database;
    return await db.query('vocabularies');
  }

  Future<List<Map<String, dynamic>>> getVocabulariesByLanguage(
    String language,
  ) async {
    final db = await database;
    return await db.query(
      'vocabularies',
      where: 'language = ?',
      whereArgs: [language],
    );
  }

  Stream<List<Map<String, dynamic>>> watchAllVocabularies() async* {
    yield await getAllVocabularies();
    yield* _getController('vocabularies').stream;
  }

  Future<int> deleteVocabulary(String word) async {
    final db = await database;
    final result = await db.delete(
      'vocabularies',
      where: 'word = ?',
      whereArgs: [word],
    );
    _notify('vocabularies');
    return result;
  }

  Future<void> insertVocabularyBatch(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'vocabularies',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notify('vocabularies');
  }

  Future<void> insertJournalsBatch(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'journals',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notify('journals');
  }

  Future<void> insertSrsBatch(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'srs_items',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _notify('srs_items');
    _notifyDueSrsItems();
  }

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
    _notify('sync_queue');
  }

  Future<List<String>> getVocabularyLanguages() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT language FROM vocabularies WHERE language IS NOT NULL AND language != ?',
      ['unknown'],
    );
    return result.map((row) => row['language'] as String).toList();
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
    _notify('sync_queue');
    return result;
  }

  Future<List<Map<String, dynamic>>> getPendingMutations() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Stream<List<Map<String, dynamic>>> watchPendingMutations() async* {
    yield await getPendingMutations();
    yield* _getController('sync_queue').stream;
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
    _notify('sync_queue');
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
    _notify('sync_queue');
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
    _notify('sync_queue');
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

  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    final db = await database;
    await db.close();
    _database = null;
  }
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
