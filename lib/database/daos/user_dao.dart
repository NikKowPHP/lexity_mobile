import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class UserDao {
  final AppDatabase _appDb;

  UserDao(this._appDb);

  Future<Database> get _database => _appDb.database;

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await _database;

    final mappedUser = {
      'id': user['id'],
      'email': user['email'],
      'native_language': user['nativeLanguage'],
      'default_target_language': user['defaultTargetLanguage'] ?? 'spanish',
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
    _appDb.notify('users');
    return result;
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    final db = await _database;
    final results = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await _database;
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
    yield* _appDb.getController('users').stream;
  }
}
