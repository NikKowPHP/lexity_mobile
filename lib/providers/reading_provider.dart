import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reading_models.dart';
import '../models/writing_aids.dart';
import '../services/reading_service.dart';
import '../services/journal_service.dart';
import 'user_provider.dart';

// Fetch material automatically
final readingMaterialProvider = FutureProvider.autoDispose<ReadingMaterial>((ref) async {
  final service = ref.watch(readingServiceProvider);
  final lang = ref.watch(activeLanguageProvider);
  return service.getMaterial(lang);
});

// Manage Task Generation State
class ReadingTaskNotifier extends StateNotifier<AsyncValue<ReadingTasksResponse?>> {
  final ReadingService _service;
  
  ReadingTaskNotifier(this._service) : super(const AsyncValue.data(null));

  Future<void> generate(String content, String lang, String level) async {
    state = const AsyncValue.loading();
    try {
      final tasks = await _service.generateTasks(
        content: content,
        targetLanguage: lang,
        level: level
      );
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final readingTaskProvider = StateNotifierProvider<ReadingTaskNotifier, AsyncValue<ReadingTasksResponse?>>((ref) {
  return ReadingTaskNotifier(ref.watch(readingServiceProvider));
});

// 3. Fetch Aids based on the generated task (NEW)
final readingAidsProvider = FutureProvider.autoDispose<WritingAids?>((
  ref,
) async {
  final taskState = ref.watch(readingTaskProvider);
  final lang = ref.watch(activeLanguageProvider);
  final journalService = ref.watch(journalServiceProvider);

  // Only fetch aids if we have a generated task
  if (taskState.value != null) {
    final topic = taskState.value!.summary.title;
    return journalService.getWritingAids(topic, lang);
  }
  return null;
});
