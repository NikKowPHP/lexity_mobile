import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading_models.dart';
import '../models/writing_aids.dart';
import '../services/reading_service.dart';
import '../services/journal_service.dart';
import 'user_provider.dart';

final readingMaterialProvider = FutureProvider.autoDispose<ReadingMaterial>((
  ref,
) async {
  final service = ref.watch(readingServiceProvider);
  final lang = ref.watch(activeLanguageProvider);
  return service.getMaterial(lang);
});

class ReadingTaskNotifier extends AsyncNotifier<ReadingTasksResponse?> {
  @override
  Future<ReadingTasksResponse?> build() async {
    return null;
  }

  Future<void> generate(String content, String lang, String level) async {
    state = const AsyncValue.loading();
    try {
      final tasks = await ref
          .read(readingServiceProvider)
          .generateTasks(content: content, targetLanguage: lang, level: level);
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final readingTaskProvider =
    AsyncNotifierProvider<ReadingTaskNotifier, ReadingTasksResponse?>(() {
      return ReadingTaskNotifier();
    });

final readingAidsProvider = FutureProvider.autoDispose<WritingAids?>((
  ref,
) async {
  final taskState = ref.watch(readingTaskProvider);
  final lang = ref.watch(activeLanguageProvider);
  final journalService = ref.watch(journalServiceProvider);

  if (taskState.value != null) {
    final topic = taskState.value!.summary.title;
    return journalService.getWritingAids(topic, lang);
  }
  return null;
});
