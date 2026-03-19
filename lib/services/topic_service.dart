import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/network/api_client.dart';
import 'package:lexity_mobile/services/logger_service.dart';
import 'package:lexity_mobile/database/app_database.dart';

class TopicService {
  final ApiClient _client;
  final AppDatabase _db;
  late final LoggerService _logger;

  TopicService(this._client, this._db, LoggerService logger) : _logger = logger;

  /// Fetch suggested topics from local DB
  Future<List<String>> getLocalTopics(String targetLanguage) async {
    try {
      final topics = await _db.getTopics(targetLanguage);
      return topics.map((t) => t['title'] as String).toList();
    } catch (e) {
      _logger.warning('TopicService: Error fetching local topics: $e');
      return [];
    }
  }

  /// Fetch topics from remote API (generates new ones)
  Future<List<String>> generateTopics(String targetLanguage) async {
    try {
      _logger.info('TopicService: Generating topics for $targetLanguage');

      final response = await _client.get<Map<String, dynamic>>(
        '/api/user/generate-topics',
        queryParameters: {'targetLanguage': targetLanguage},
      );

      if (response.statusCode == 200 && response.data != null) {
        final topics = response.data!['topics'] as List<dynamic>? ?? [];
        final topicList = topics.map((t) => t.toString()).toList();

        // Save to local DB for offline reuse
        await _saveTopicsToLocal(targetLanguage, topicList);

        _logger.info('TopicService: Generated ${topicList.length} topics');
        return topicList;
      }

      _logger.warning(
        'TopicService: Unexpected response: ${response.statusCode}',
      );
      return [];
    } catch (e, stackTrace) {
      _logger.error('TopicService: Error generating topics', e, stackTrace);

      // Fallback to local topics if API fails
      final localTopics = await getLocalTopics(targetLanguage);
      if (localTopics.isNotEmpty) {
        _logger.info('TopicService: Using ${localTopics.length} cached topics');
        return localTopics;
      }
      return _getDefaultTopics(targetLanguage);
    }
  }

  /// Fetch suggested topics from API (without generating new ones)
  Future<List<String>> fetchSuggestedTopics(String targetLanguage) async {
    try {
      _logger.info(
        'TopicService: Fetching suggested topics for $targetLanguage',
      );

      final response = await _client.get<Map<String, dynamic>>(
        '/api/user/suggested-topics',
        queryParameters: {'targetLanguage': targetLanguage},
      );

      if (response.statusCode == 200 && response.data != null) {
        final topics = response.data!['topics'] as List<dynamic>? ?? [];
        final topicList = topics.map((t) => t.toString()).toList();

        // Cache locally
        await _saveTopicsToLocal(targetLanguage, topicList);

        return topicList;
      }

      return [];
    } catch (e) {
      _logger.warning('TopicService: Error fetching suggested topics: $e');
      // Fallback to local
      return getLocalTopics(targetLanguage);
    }
  }

  Future<void> _saveTopicsToLocal(String language, List<String> topics) async {
    try {
      await _db.clearTopics(language);
      for (final title in topics) {
        await _db.insertTopic({
          'title': title,
          'target_language': language,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      _logger.warning('TopicService: Error saving topics locally: $e');
    }
  }

  /// Fallback topics when offline and no cache
  List<String> _getDefaultTopics(String language) {
    // Return some generic starter topics based on language
    final Map<String, List<String>> defaultTopics = {
      'es': [
        'Mi día laboral',
        'Una comida típica',
        'Mis metas para este año',
        'Un recuerdo de infancia',
        'Mi lugar favorito',
      ],
      'fr': [
        'Ma journée de travail',
        'Un repas typique',
        'Mes objectifs cette année',
        'Un souvenir d\'enfance',
        'Mon lieu préféré',
      ],
      'de': [
        'Mein Arbeitstag',
        'Ein typisches Essen',
        'Meine Ziele für dieses Jahr',
        'Eine Kindheitserinnerung',
        'Mein Lieblingsort',
      ],
      // Default for other languages
      'default': [
        'My workday',
        'A typical meal',
        'My goals for this year',
        'A childhood memory',
        'My favorite place',
      ],
    };

    return defaultTopics[language] ?? defaultTopics['default']!;
  }
}

final topicServiceProvider = Provider<TopicService>((ref) {
  final logger = ref.watch(loggerProvider);

  // Return a version that skips API calls if offline
  final service = TopicService(
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider),
    logger,
  );

  return service;
});
