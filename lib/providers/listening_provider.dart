import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/listening_models.dart';
import '../models/writing_aids.dart';
import '../services/listening_service.dart';
import '../services/journal_service.dart';
import 'user_provider.dart';

// 1. Fetch Exercise
final listeningExerciseProvider = FutureProvider.autoDispose<ListeningExercise>((ref) async {
  final service = ref.watch(listeningServiceProvider);
  final lang = ref.watch(activeLanguageProvider);
  return service.getExercise(lang);
});

// 2. Task Generation State
class ListeningTaskNotifier extends StateNotifier<AsyncValue<ListeningTasksResponse?>> {
  final ListeningService _service;
  
  ListeningTaskNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> generate(String exerciseId) async {
    state = const AsyncValue.loading();
    try {
      final tasks = await _service.generateTasks(exerciseId);
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final listeningTaskProvider = StateNotifierProvider<ListeningTaskNotifier, AsyncValue<ListeningTasksResponse?>>((ref) {
  return ListeningTaskNotifier(ref.watch(listeningServiceProvider));
});

// 3. Fetch Aids based on the generated task
final listeningAidsProvider = FutureProvider.autoDispose<WritingAids?>((ref) async {
  final taskState = ref.watch(listeningTaskProvider);
  final lang = ref.watch(activeLanguageProvider);
  final journalService = ref.watch(journalServiceProvider);

  if (taskState.value != null) {
    // We use the summary task title to generate relevant aids
    final topic = taskState.value!.summary.title;
    return journalService.getWritingAids(topic, lang);
  }
  return null;
});
