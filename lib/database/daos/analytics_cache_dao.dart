import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../utils/isolate_json_parser.dart';

class AnalyticsCacheDao {
  final AppDatabase _appDb;

  AnalyticsCacheDao(this._appDb);

  Future<Database> get _database => _appDb.database;

  Future<void> cacheAnalytics(
    String targetLanguage,
    Map<String, dynamic> data,
  ) async {
    try {
      final db = await _database;
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
      final db = await _database;
      final results = await db.query(
        'analytics_cache',
        where: 'target_language = ?',
        whereArgs: [targetLanguage],
        orderBy: 'fetched_at DESC',
        limit: 1,
      );
      if (results.isEmpty) return null;
      final jsonStr = results.first['data_json'] as String;
      return await IsolateJsonParser.parseJson(jsonStr);
    } catch (e) {
      return null;
    }
  }
}
