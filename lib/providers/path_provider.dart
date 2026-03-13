import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learning_module.dart';
import '../services/learning_path_service.dart';
import 'user_provider.dart';
import '../services/journal_service.dart';

final learningPathProvider = FutureProvider.autoDispose<List<LearningModule>>((ref) async {
  final service = ref.watch(learningPathServiceProvider);
  final activeLang = ref.watch(activeLanguageProvider);
  return service.getPath(activeLang);
});

class PathNotifier extends StateNotifier<AsyncValue<void>> {
  final LearningPathService _service;
  final Ref _ref;

  PathNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<void> generateNextModule() async {
    state = const AsyncValue.loading();
    try {
      final activeLang = _ref.read(activeLanguageProvider);
      await _service.generateNextModule(activeLang);
      _ref.invalidate(learningPathProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> completeModule(String moduleId) async {
    state = const AsyncValue.loading();
    try {
      await _service.completeModule(moduleId);
      _ref.invalidate(learningPathProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateActivity(String moduleId, String activityKey, bool isCompleted, [Map<String, dynamic>? metadata]) async {
    try {
      await _service.updateActivity(moduleId, activityKey, isCompleted, metadata);
      _ref.invalidate(learningPathProvider); // Refresh to show checkmarks
    } catch (e) {
      // Handle error
    }
  }

  void startSelfHealing(String journalId) {
    // Replicates the web's 60s timeout re-trigger
    Future.delayed(const Duration(seconds: 60), () async {
      try {
        // If analysis seems stuck, we can re-trigger journal analysis
        await _ref.read(journalServiceProvider).analyzeEntry(journalId);
        _ref.invalidate(learningPathProvider);
      } catch (e) {
        // Silent fail for healing
      }
    });
  }
}

final pathNotifierProvider = StateNotifierProvider<PathNotifier, AsyncValue<void>>((ref) {
  return PathNotifier(ref.watch(learningPathServiceProvider), ref);
});
