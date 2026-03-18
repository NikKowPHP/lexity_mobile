import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/listening_models.dart';
import '../models/writing_aids.dart';
import '../services/listening_service.dart';
import '../services/journal_service.dart';
import 'user_provider.dart';

final listeningExerciseProvider = FutureProvider.autoDispose<ListeningExercise>(
  (ref) async {
    final service = ref.watch(listeningServiceProvider);
    final lang = ref.watch(activeLanguageProvider);
    return service.getExercise(lang);
  },
);

class ListeningTaskNotifier extends AsyncNotifier<ListeningTasksResponse?> {
  @override
  Future<ListeningTasksResponse?> build() async {
    return null;
  }

  Future<void> generate(String exerciseId) async {
    state = const AsyncValue.loading();
    try {
      final tasks = await ref
          .read(listeningServiceProvider)
          .generateTasks(exerciseId);
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final listeningTaskProvider =
    AsyncNotifierProvider<ListeningTaskNotifier, ListeningTasksResponse?>(() {
      return ListeningTaskNotifier();
    });

final listeningAidsProvider = FutureProvider.autoDispose<WritingAids?>((
  ref,
) async {
  final taskState = ref.watch(listeningTaskProvider);
  final lang = ref.watch(activeLanguageProvider);
  final journalService = ref.watch(journalServiceProvider);

  if (taskState.value != null) {
    final topic = taskState.value!.summary.title;
    return journalService.getWritingAids(topic, lang);
  }
  return null;
});
