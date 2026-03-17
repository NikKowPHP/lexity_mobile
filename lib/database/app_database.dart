import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppDatabase {
  static Database? _database;
  static const String _dbName = 'lexity.db';
  static const int _dbVersion = 4;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    // NOTE: Database migrations are handled in _onUpgrade
    // Do NOT delete the database here - it would wipe all cached data

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

    // Map API field names to SQLite column names
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

    return await db.insert(
      'users',
      mappedUser,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    final db = await database;
    final results = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    final results = await db.query('users');

    // Convert back to API format for UserProfile.fromJson
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
    final db = await database;
    yield* Stream.periodic(
      const Duration(milliseconds: 500),
    ).asyncMap((_) => db.query('users'));
  }

  // Books
  Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await database;
    return await db.insert(
      'books',
      book,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    final db = await database;
    yield* Stream.periodic(
      const Duration(milliseconds: 500),
    ).asyncMap((_) => db.query('books'));
  }

  Future<int> updateBookProgress(String id, String cfi, double progress) async {
    final db = await database;
    return await db.update(
      'books',
      {'current_cfi': cfi, 'progress_pct': progress},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteBook(String id) async {
    final db = await database;
    return await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  // Journals
  Future<int> insertJournal(Map<String, dynamic> journal) async {
    final db = await database;
    return await db.insert(
      'journals',
      journal,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    final db = await database;
    yield* Stream.periodic(
      const Duration(milliseconds: 500),
    ).asyncMap((_) => db.query('journals', orderBy: 'created_at DESC'));
  }

  // SRS Items
  Future<int> insertSrsItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert(
      'srs_items',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllSrsItems() async {
    final db = await database;
    return await db.query('srs_items');
  }

  Stream<List<Map<String, dynamic>>> watchAllSrsItems() async* {
    final db = await database;
    yield* Stream.periodic(
      const Duration(milliseconds: 500),
    ).asyncMap((_) => db.query('srs_items'));
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

  Stream<List<Map<String, dynamic>>> watchDueSrsItems() async* {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    yield* Stream.periodic(const Duration(milliseconds: 500)).asyncMap(
      (_) => db.query(
        'srs_items',
        where: 'next_review_date <= ?',
        whereArgs: [now],
      ),
    );
  }

  Future<int> updateSrsItemReviewDate(String id, DateTime nextReview) async {
    final db = await database;
    return await db.update(
      'srs_items',
      {'next_review_date': nextReview.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Vocabularies
  Future<int> insertVocabulary(Map<String, dynamic> vocab) async {
    final db = await database;
    return await db.insert(
      'vocabularies',
      vocab,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllVocabularies() async {
    final db = await database;
    return await db.query('vocabularies');
  }

  Stream<List<Map<String, dynamic>>> watchAllVocabularies() async* {
    final db = await database;
    yield* Stream.periodic(
      const Duration(milliseconds: 500),
    ).asyncMap((_) => db.query('vocabularies'));
  }

  Future<int> deleteVocabulary(String word) async {
    final db = await database;
    return await db.delete(
      'vocabularies',
      where: 'word = ?',
      whereArgs: [word],
    );
  }

  // Sync Queue
  Future<int> enqueueMutation(Map<String, dynamic> mutation) async {
    final db = await database;

    // OPTIMIZATION: If this is a book progress update, remove older pending
    // progress updates for the same book to keep the queue slim.
    if (mutation['entity_type'] == 'book' &&
        mutation['action'] == 'update_progress') {
      await db.delete(
        'sync_queue',
        where: 'entity_type = ? AND action = ? AND entity_id = ?',
        whereArgs: ['book', 'update_progress', mutation['entity_id']],
      );
    }

    return await db.insert('sync_queue', {
      ...mutation,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingMutations() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Stream<List<Map<String, dynamic>>> watchPendingMutations() async* {
    final db = await database;
    yield* Stream.periodic(
      const Duration(milliseconds: 500),
    ).asyncMap((_) => db.query('sync_queue', orderBy: 'created_at ASC'));
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
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
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
