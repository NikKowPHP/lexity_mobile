import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/journal_entry.dart';
import '../../models/writing_aids.dart';
import '../../database/repositories/sync_repository.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/logger_service.dart';
import '../datasources/remote/journal_remote_datasource.dart';
import '../datasources/local/journal_local_datasource.dart';

class JournalRepository {
  final Ref _ref;
  final JournalRemoteDataSource _remoteDataSource;
  final JournalLocalDataSource _localDataSource;
  final SyncRepository _syncRepo;
  late final LoggerService _logger;
  final _uuid = const Uuid();
  static final Map<String, WritingAids> _aidsCache = {};

  JournalRepository(
    this._ref,
    this._remoteDataSource,
    this._localDataSource,
    this._syncRepo,
  ) {
    _logger = _ref.read(loggerProvider);
  }

  Future<List<JournalEntry>> getHistory(String targetLanguage) async {
    _syncHistoryInBackground(targetLanguage);
    return _localDataSource.getAllJournals();
  }

  void _syncHistoryInBackground(String targetLanguage) {
    if (!_ref.read(connectivityProvider)) return;
    Future(() async {
      try {
        final remoteData = await _remoteDataSource.getHistory(targetLanguage);
        for (final item in remoteData) {
          await _localDataSource.upsertFromRemote(item);
        }
        _logger.info(
          'JournalRepository: Background sync complete, ${remoteData.length} entries upserted',
        );
      } catch (e, st) {
        _logger.warning('JournalRepository: Background sync failed', e, st);
      }
    });
  }

  Future<JournalEntry> getEntry(String id) async {
    _syncEntryInBackground(id);
    final local = await _localDataSource.getJournalById(id);
    if (local != null) return local;
    throw Exception('Journal entry not found');
  }

  void _syncEntryInBackground(String id) {
    if (!_ref.read(connectivityProvider)) return;
    Future(() async {
      try {
        final data = await _remoteDataSource.getEntry(id);
        await _localDataSource.upsertFromRemote(data);
        _logger.info(
          'JournalRepository: Background sync complete for entry $id',
        );
      } catch (e, st) {
        _logger.warning(
          'JournalRepository: Background sync failed for entry $id',
          e,
          st,
        );
      }
    });
  }

  Future<JournalEntry> createEntry(
    String content,
    String title,
    String targetLanguage, {
    String? moduleId,
  }) async {
    final tempId = _uuid.v4();

    await _localDataSource.insertJournal({
      'id': tempId,
      'content': content,
      'title': title,
      'createdAt': DateTime.now(),
      'isPending': true,
    });

    await _syncRepo.enqueueJournalCreate(
      tempId,
      title,
      content,
      targetLanguage,
      moduleId,
      'free_write',
    );

    return JournalEntry(
      id: tempId,
      content: content,
      title: title,
      createdAt: DateTime.now(),
      isPending: true,
    );
  }

  Future<void> updateEntry(String id, String content, String title) async {
    _logger.info('JournalRepository: Updating entry $id');
    await _remoteDataSource.updateEntry(id, content, title);
  }

  Future<JournalEntry> createAudioEntry(
    String filePath,
    String targetLanguage, {
    String? moduleId,
  }) async {
    final isOnline = _ref.read(connectivityProvider);

    if (!isOnline) {
      return _createAudioEntryOffline(filePath, targetLanguage, moduleId);
    }

    _logger.info('JournalRepository: Starting audio journal creation');

    final file = File(filePath);
    final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.webm';
    final bytes = await file.readAsBytes();

    final urlData = await _remoteDataSource.generateUploadUrl(filename);
    var signedUrl = urlData['signedUrl'] as String;
    final storagePath = urlData['path'];

    if (signedUrl.startsWith('/')) {
      signedUrl = 'https://www.lexity.app$signedUrl';
    }

    await _remoteDataSource.uploadFile(signedUrl, bytes, 'audio/webm');

    final responseData = await _remoteDataSource.createAudioEntry(
      path: storagePath,
      targetLanguage: targetLanguage,
      moduleId: moduleId,
    );

    await _localDataSource.upsertFromRemote(responseData);
    return JournalEntry.fromJson(responseData);
  }

  Future<JournalEntry> _createAudioEntryOffline(
    String filePath,
    String targetLanguage,
    String? moduleId,
  ) async {
    _logger.info(
      'JournalRepository: Saving audio journal locally for offline upload',
    );

    final tempId = _uuid.v4();

    await _localDataSource.insertJournal({
      'id': tempId,
      'content': '',
      'title': 'Audio Recording',
      'createdAt': DateTime.now(),
      'audioUrl': filePath,
      'isPending': true,
    });

    await _syncRepo.enqueueMutation(
      entityType: 'journal',
      action: 'upload_audio',
      entityId: tempId,
      payload: {
        'localFilePath': filePath,
        'targetLanguage': targetLanguage,
        'moduleId': moduleId,
      },
    );

    return JournalEntry(
      id: tempId,
      content: '',
      title: 'Audio Recording',
      createdAt: DateTime.now(),
      audioUrl: filePath,
      isPending: true,
    );
  }

  Future<void> deleteEntry(String id) async {
    _logger.info('JournalRepository: Deleting entry $id');
    await _localDataSource.deleteJournal(id);
  }

  Future<void> analyzeEntry(String id) async {
    final isOnline = _ref.read(connectivityProvider);

    if (!isOnline) {
      _logger.warning(
        'JournalRepository: Cannot analyze entry while offline. Queuing analysis.',
      );
      await _syncRepo.enqueueMutation(
        entityType: 'journal',
        action: 'analyze',
        entityId: id,
        payload: {},
      );
      return;
    }

    _logger.info('JournalRepository: Starting analysis for $id');
    await _remoteDataSource.analyzeEntry(id);
  }

  Future<List<String>> getSuggestedTopics(String targetLanguage) async {
    if (!_ref.read(connectivityProvider)) {
      return [];
    }
    return _remoteDataSource.getSuggestedTopics(targetLanguage);
  }

  Future<void> generateTopics(String targetLanguage) async {
    if (!_ref.read(connectivityProvider)) {
      return;
    }
    await _remoteDataSource.generateTopics(targetLanguage);
  }

  Future<WritingAids> getWritingAids(
    String topic,
    String targetLanguage,
  ) async {
    final cacheKey = 'aids_${topic}_$targetLanguage';
    
    if (_aidsCache.containsKey(cacheKey)) {
      return _aidsCache[cacheKey]!;
    }
    
    if (!_ref.read(connectivityProvider)) {
      throw Exception('Writing aids require internet connection');
    }
    
    final data = await _remoteDataSource.getWritingAids(topic, targetLanguage);
    final result = WritingAids.fromJson(data);
    _aidsCache[cacheKey] = result;
    return result;
  }

  Stream<List<JournalEntry>> watchJournals() {
    return _localDataSource.watchJournals();
  }
}

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(
    ref,
    ref.watch(journalRemoteDataSourceProvider),
    ref.watch(journalLocalDataSourceProvider),
    ref.watch(syncRepositoryProvider),
  );
});
