import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/repositories/sync_repository.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/logger_service.dart';
import '../../services/sync_service.dart';
import '../datasources/remote/vocabulary_remote_datasource.dart';
import '../datasources/local/vocabulary_local_datasource.dart';

class VocabularyRepository {
  final Ref _ref;
  final VocabularyRemoteDataSource _remoteDataSource;
  final VocabularyLocalDataSource _localDataSource;
  final SyncRepository _syncRepo;
  late final LoggerService _logger;

  VocabularyRepository(
    this._ref,
    this._remoteDataSource,
    this._localDataSource,
    this._syncRepo,
  ) {
    _logger = _ref.read(loggerProvider);
  }

  Future<Map<String, String>> getVocabulary(String language) async {
    _syncVocabularyInBackground(language);
    return _localDataSource.getVocabulary(language);
  }

  void _syncVocabularyInBackground(String language) {
    if (!_ref.read(connectivityProvider)) return;
    Future(() async {
      try {
        final remoteVocab = await _remoteDataSource.getVocabulary(language);
        for (final entry in remoteVocab.entries) {
          await _localDataSource.upsertFromRemote({
            'word': entry.key,
            'status': entry.value,
          }, language);
        }
        _logger.info(
          'VocabularyRepository: Background sync complete, ${remoteVocab.length} words upserted',
        );
      } catch (e, st) {
        _logger.warning('VocabularyRepository: Background sync failed', e, st);
      }
    });
  }

  Future<VocabularyPageResult> getVocabularyPage(
    String language, {
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    _syncVocabularyPageInBackground(
      language,
      page: page,
      limit: limit,
      status: status,
    );
    return _getLocalVocabularyPage(language);
  }

  void _syncVocabularyPageInBackground(
    String language, {
    int page = 1,
    int limit = 50,
    String? status,
  }) {
    if (!_ref.read(connectivityProvider)) return;
    Future(() async {
      try {
        final result = await _remoteDataSource.getVocabularyPage(
          language,
          page: page,
          limit: limit,
          status: status,
        );
        for (final entry in result.items.entries) {
          await _localDataSource.upsertFromRemote({
            'word': entry.key,
            'status': entry.value,
          }, language);
        }
        _logger.info(
          'VocabularyRepository: Background page sync complete for page $page',
        );
      } catch (e, st) {
        _logger.warning(
          'VocabularyRepository: Background page sync failed',
          e,
          st,
        );
      }
    });
  }

  Future<VocabularyPageResult> _getLocalVocabularyPage(String language) async {
    final items = await _localDataSource.getAllVocabulary();

    int known = 0, learning = 0, unknown = 0;

    for (final item in items.values) {
      if (item == 'known') {
        known++;
      } else if (item == 'learning') {
        learning++;
      } else {
        unknown++;
      }
    }

    return VocabularyPageResult(
      items: items,
      totalCount: items.length,
      totalPages: 1,
      currentPage: 1,
      counts: VocabularyCounts(
        total: items.length,
        known: known,
        learning: learning,
        unknown: unknown,
      ),
    );
  }

  Future<void> updateStatus(String word, String status, String language) async {
    _logger.info(
      'VocabularyRepository: Updating status for "$word" to "$status" locally',
    );

    await _localDataSource.updateStatus(word, status, language);

    await _syncRepo.enqueueVocabUpdate(word.toLowerCase(), status, language);

    _logger.info('VocabularyRepository: Status update queued for sync');

    if (_ref.read(connectivityProvider)) {
      _logger.info(
        'VocabularyRepository: Online, triggering immediate sync...',
      );
      _ref.read(syncServiceProvider).syncPendingMutations(force: true);
    }
  }

  Future<void> markBatchKnown(List<String> words, String language) async {
    _logger.info(
      'VocabularyRepository: Marking ${words.length} words as known locally',
    );

    final lowerWords = words.map((w) => w.toLowerCase()).toList();
    final batchItems = lowerWords
        .map((word) => {'word': word, 'status': 'known'})
        .toList();

    await _localDataSource.upsertBatch(batchItems, language);

    await _syncRepo.enqueueVocabBatchUpdate(lowerWords, 'known', language);

    _logger.info('VocabularyRepository: Batch update queued for sync');

    if (_ref.read(connectivityProvider)) {
      _logger.info(
        'VocabularyRepository: Online, triggering immediate sync...',
      );
      _ref.read(syncServiceProvider).syncPendingMutations(force: true);
    }
  }

  Future<void> deleteWord(String word, String language) async {
    _logger.info('VocabularyRepository: Deleting word "$word" locally');
    await _localDataSource.deleteWord(word);
  }

  Stream<Map<String, String>> watchVocabulary() {
    return _localDataSource.watchVocabulary();
  }
}

final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  return VocabularyRepository(
    ref,
    ref.watch(vocabularyRemoteDataSourceProvider),
    ref.watch(vocabularyLocalDataSourceProvider),
    ref.watch(syncRepositoryProvider),
  );
});
