import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learning_module.dart';
import '../database/app_database.dart';
import '../providers/connectivity_provider.dart';
import 'logger_service.dart';
import '../network/api_client.dart';

class LearningPathService {
  final Ref _ref;
  final ApiClient _client;
  final AppDatabase _db;
  late final LoggerService _logger;

  LearningPathService(this._ref, this._client, this._db) {
    _logger = _ref.read(loggerProvider);
  }

  bool get _isOnline => _ref.read(connectivityProvider);

  Future<List<LearningModule>> getPath(String language) async {
    _logger.info('LearningPathService: Fetching path for $language');

    if (!_isOnline) {
      _logger.warning('LearningPathService: Offline, trying cache');
      final cached = await _db.getCachedLearningModules(language);
      if (cached.isNotEmpty) {
        return cached.map((e) => LearningModule.fromJson(e)).toList();
      }
      throw Exception('No cached learning path available offline');
    }

    try {
      final response = await _client.get(
        '/api/learning-path',
        queryParameters: {'targetLanguage': language},
      );

      if (response.statusCode == 200) {
        final List data = response.data;
        await _db.cacheLearningModules(
          language,
          data.cast<Map<String, dynamic>>(),
        );

        _prefetchNextModules(language);

        return data.map((e) => LearningModule.fromJson(e)).toList();
      }
      throw Exception('Failed to load learning path');
    } catch (e) {
      _logger.warning('LearningPathService: API failed, trying cache: $e');
      final cached = await _db.getCachedLearningModules(language);
      if (cached.isNotEmpty) {
        return cached.map((e) => LearningModule.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  Future<void> _prefetchNextModules(String language) async {
    if (!_isOnline) {
      _logger.info('LearningPathService: Offline, skipping prefetch');
      return;
    }

    try {
      _logger.info('LearningPathService: Pre-fetching next modules');
      final response = await _client.put(
        '/api/learning-path/prefetch',
        queryParameters: {'targetLanguage': language},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _logger.info(
          'LearningPathService: Pre-fetched ${data['cachedModules'] ?? 0} modules on server',
        );

        await _db.cacheLearningModules(language, []);
        final cached = await _db.getCachedLearningModules(language);
        final existingIds = cached.map((e) => e['id'] as String).toSet();

        final refreshResponse = await _client.get(
          '/api/learning-path',
          queryParameters: {'targetLanguage': language},
        );

        if (refreshResponse.statusCode == 200) {
          final List modulesData = refreshResponse.data;
          for (final module in modulesData) {
            if (!existingIds.contains(module['id'])) {
              await _db.insertLearningModule({
                'id': module['id'],
                'language': language,
                'title': module['title'] ?? '',
                'status': module['status'] ?? 'PENDING',
                'target_concept_tag': module['targetConceptTag'] ?? '',
                'micro_lesson': module['microLesson'] ?? '',
                'activities_json': jsonEncode(module['activities'] ?? {}),
                'completed_at': module['completedAt'] != null
                    ? DateTime.parse(
                        module['completedAt'],
                      ).millisecondsSinceEpoch
                    : null,
                'last_synced_at': DateTime.now().millisecondsSinceEpoch,
              });
            }
          }
          _logger.info(
            'LearningPathService: Local DB synced with ${modulesData.length} modules',
          );
        }
      } else {
        _logger.warning(
          'LearningPathService: Prefetch failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.warning('LearningPathService: Prefetch failed: $e');
    }
  }

  Future<void> generateNextModule(String language) async {
    _logger.info('LearningPathService: Generating next module');

    if (!_isOnline) {
      throw Exception('Cannot generate new module while offline');
    }

    final response = await _client.post(
      '/api/learning-path/generate-next-module',
      data: {'targetLanguage': language},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate next module');
    }
  }

  Future<void> updateActivity(
    String moduleId,
    String activityKey,
    bool isCompleted, [
    Map<String, dynamic>? metadata,
  ]) async {
    if (!_isOnline) {
      throw Exception('Cannot update activity while offline');
    }

    await _client.put(
      '/api/learning-path/modules/$moduleId/activity',
      data: {
        'activityKey': activityKey,
        'isCompleted': isCompleted,
        'metadata': metadata,
      },
    );
  }

  Future<LearningModule> completeModule(
    String moduleId, {
    bool skip = false,
  }) async {
    if (!_isOnline) {
      throw Exception('Cannot complete module while offline');
    }

    final response = await _client.post(
      '/api/learning-path/modules/$moduleId/complete',
      data: {'skip': skip},
    );

    if (response.statusCode == 200) {
      return LearningModule.fromJson(response.data);
    }
    throw Exception('Failed to complete module');
  }
}

final learningPathServiceProvider = Provider(
  (ref) => LearningPathService(
    ref,
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider),
  ),
);
