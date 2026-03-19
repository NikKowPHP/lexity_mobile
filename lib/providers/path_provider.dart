import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learning_module.dart';
import '../services/learning_path_service.dart';
import 'user_provider.dart';
import '../data/repositories/journal_repository.dart';

final learningPathProvider = FutureProvider.autoDispose<List<LearningModule>>((
  ref,
) async {
  final service = ref.watch(learningPathServiceProvider);
  final activeLang = ref.watch(activeLanguageProvider);
  return service.getPath(activeLang);
});

class PathNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> generateNextModule() async {
    final service = ref.read(learningPathServiceProvider);
    state = const AsyncValue.loading();
    try {
      final activeLang = ref.read(activeLanguageProvider);
      await service.generateNextModule(activeLang);
      ref.invalidate(learningPathProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> completeModule(String moduleId) async {
    final service = ref.read(learningPathServiceProvider);
    state = const AsyncValue.loading();
    try {
      await service.completeModule(moduleId);
      ref.invalidate(learningPathProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateActivity(
    String moduleId,
    String activityKey,
    bool isCompleted, [
    Map<String, dynamic>? metadata,
  ]) async {
    try {
      final service = ref.read(learningPathServiceProvider);
      await service.updateActivity(
        moduleId,
        activityKey,
        isCompleted,
        metadata,
      );
      ref.invalidate(learningPathProvider);
    } catch (e) {}
  }

  void startSelfHealing(String journalId) {
    Future.delayed(const Duration(seconds: 60), () async {
      try {
        await ref.read(journalRepositoryProvider).analyzeEntry(journalId);
        ref.invalidate(learningPathProvider);
      } catch (e) {}
    });
  }
}

final pathNotifierProvider = NotifierProvider<PathNotifier, AsyncValue<void>>(
  () {
    return PathNotifier();
  },
);
