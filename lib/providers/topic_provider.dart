import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/topic_service.dart';
import 'package:lexity_mobile/providers/user_provider.dart';
import 'package:lexity_mobile/providers/connectivity_provider.dart';

/// State for topics
class TopicsState {
  final List<String> topics;
  final bool isLoading;
  final String? error;

  const TopicsState({
    this.topics = const [],
    this.isLoading = false,
    this.error,
  });

  TopicsState copyWith({List<String>? topics, bool? isLoading, String? error}) {
    return TopicsState(
      topics: topics ?? this.topics,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for managing topics state
class TopicsNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    // Get the target language from user profile
    final targetLanguage = ref.watch(activeLanguageProvider);
    return _loadTopics(targetLanguage);
  }

  Future<List<String>> _loadTopics(String language) async {
    final topicService = ref.read(topicServiceProvider);

    // First try local
    final localTopics = await topicService.getLocalTopics(language);
    if (localTopics.isNotEmpty) {
      return localTopics;
    }

    // If empty, try to generate/fetch
    return await topicService.generateTopics(language);
  }

  /// Generate new topics from AI
  Future<void> generateTopics() async {
    state = const AsyncValue.loading();

    try {
      final targetLanguage = ref.read(activeLanguageProvider);
      final topicService = ref.read(topicServiceProvider);
      final topics = await topicService.generateTopics(targetLanguage);
      state = AsyncValue.data(topics);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh topics from API
  Future<void> refresh() async {
    state = const AsyncValue.loading();

    try {
      final targetLanguage = ref.read(activeLanguageProvider);
      final topicService = ref.read(topicServiceProvider);
      final topics = await topicService.generateTopics(targetLanguage);
      state = AsyncValue.data(topics);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Get cached topics without loading
  Future<List<String>> getLocalTopics() async {
    final targetLanguage = ref.read(activeLanguageProvider);
    final topicService = ref.read(topicServiceProvider);
    return await topicService.getLocalTopics(targetLanguage);
  }
}

final topicsProvider = AsyncNotifierProvider<TopicsNotifier, List<String>>(() {
  return TopicsNotifier();
});

/// Provider to check if we should show topic selection
final showTopicSelectionProvider = Provider<bool>((ref) {
  final isOnline = ref.watch(connectivityProvider);
  // Show topic selection if online, or if there are cached topics
  if (isOnline) return true;

  final topicsAsync = ref.watch(topicsProvider);
  return topicsAsync.maybeWhen(
    data: (topics) => topics.isNotEmpty,
    orElse: () => false,
  );
});
