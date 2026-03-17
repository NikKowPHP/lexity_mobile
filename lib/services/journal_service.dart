import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/services/token_service.dart';
import 'package:uuid/uuid.dart';
import 'logger_service.dart';
import '../models/journal_entry.dart';
import '../models/writing_aids.dart';
import '../utils/constants.dart';
import '../database/app_database.dart';
import '../database/repositories/sync_repository.dart';
import '../providers/connectivity_provider.dart';

class JournalService {
  final Ref _ref;
  final TokenService _authTokenService;
  final AppDatabase _db;
  final SyncRepository _syncRepo;
  late final LoggerService _logger;
  final _uuid = const Uuid();

  JournalService(this._ref, this._authTokenService, this._db, this._syncRepo) {
    _logger = _ref.read(loggerProvider);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<JournalEntry>> getHistory(String targetLanguage) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse(
            '${AppConstants.baseUrl}/api/journal?targetLanguage=$targetLanguage',
          ),
          headers: await _getHeaders(),
        );

        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);

          for (final item in data) {
            await _upsertJournalLocal(item);
          }

          return data.map((e) => JournalEntry.fromJson(e)).toList();
        }
      } catch (e, st) {
        _logger.warning('JournalService: Failed to fetch from backend', e, st);
      }
    }

    return _getLocalJournals();
  }

  Future<List<JournalEntry>> _getLocalJournals() async {
    final journals = await _db.getAllJournals();
    return journals.map((map) => _journalFromDb(map)).toList();
  }

  Future<void> _upsertJournalLocal(Map<String, dynamic> data) async {
    final analysis = data['analysis'];
    await _db.insertJournal({
      'id': data['id'],
      'content': data['content'] ?? '',
      'title': data['topic']?['title'] ?? 'Free Write',
      'created_at': DateTime.parse(data['createdAt']).millisecondsSinceEpoch,
      'audio_url': data['audioUrl'],
      'is_pending_analysis': analysis == null ? 0 : 0,
      'analysis_json': analysis != null ? jsonEncode(analysis) : null,
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  JournalEntry _journalFromDb(Map<String, dynamic> map) {
    Analysis? analysis;
    if (map['analysis_json'] != null) {
      try {
        final analysisData = jsonDecode(map['analysis_json'] as String);
        analysis = Analysis.fromJson(analysisData);
      } catch (e) {
        _logger.warning('JournalService: Failed to parse analysis JSON', e);
      }
    }

    return JournalEntry(
      id: map['id'] as String,
      content: map['content'] as String,
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      audioUrl: map['audio_url'] as String?,
      analysis: analysis,
      isPending: (map['is_pending_analysis'] as int?) == 1,
    );
  }

  Future<JournalEntry> getEntry(String id) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('${AppConstants.baseUrl}/api/journal/$id'),
          headers: await _getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          await _upsertJournalLocal(data);
          return JournalEntry.fromJson(data);
        }
      } catch (e, st) {
        _logger.warning(
          'JournalService: Failed to fetch entry $id from backend',
          e,
          st,
        );
      }
    }

    final local = await _db.getJournalById(id);
    if (local != null) {
      return _journalFromDb(local);
    }
    throw Exception('Journal entry not found');
  }

  Future<JournalEntry> createEntry(
    String content,
    String title,
    String targetLanguage, {
    String? moduleId,
  }) async {
    final tempId = _uuid.v4();

    await _db.insertJournal({
      'id': tempId,
      'content': content,
      'title': title,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'audio_url': null,
      'is_pending_analysis': 1,
      'analysis_json': null,
      'last_synced_at': null,
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
    _logger.info('JournalService: Updating entry $id locally');
    // For simplicity, we'll require network for updates
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/api/journal/$id'),
      headers: await _getHeaders(),
      body: jsonEncode({'content': content, 'topicId': title}),
    );
    if (response.statusCode != 200) throw Exception('Failed to update entry');
  }

  Future<void> _uploadFileToSupabase(String signedUrl, File file) async {
    final bytes = await file.readAsBytes();
    final response = await http.put(
      Uri.parse(signedUrl),
      headers: {'Content-Type': 'audio/webm'},
      body: bytes,
    );
    if (response.statusCode != 200) throw Exception('Failed to upload file');
  }

  Future<JournalEntry> createAudioEntry(
    String filePath,
    String targetLanguage, {
    String? moduleId,
  }) async {
    final isOnline = _ref.read(connectivityProvider);

    if (!isOnline) {
      return await _createAudioEntryOffline(filePath, targetLanguage, moduleId);
    }

    _logger.info('JournalService: Starting audio journal creation');

    final file = File(filePath);
    final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.webm';

    final response = await http.get(
      Uri.parse(
        '${AppConstants.baseUrl}/api/journal/generate-upload-url?filename=$filename',
      ),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to generate upload URL');
    }
    final data = jsonDecode(response.body);
    var signedUrl = data['signedUrl'] as String;
    final storagePath = data['path'];

    if (signedUrl.startsWith('/')) {
      signedUrl = '${AppConstants.baseUrl}$signedUrl';
    }

    await _uploadFileToSupabase(signedUrl, file);

    final createResponse = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/journal/audio'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'path': storagePath,
        'targetLanguage': targetLanguage,
        'moduleId': moduleId,
        'aidsUsage': [],
      }),
    );

    if (createResponse.statusCode == 201) {
      final responseData = jsonDecode(createResponse.body);
      await _upsertJournalLocal(responseData);
      return JournalEntry.fromJson(responseData);
    }
    throw Exception('Failed to create audio journal record');
  }

  Future<JournalEntry> _createAudioEntryOffline(
    String filePath,
    String targetLanguage,
    String? moduleId,
  ) async {
    _logger.info(
      'JournalService: Saving audio journal locally for offline upload',
    );

    final tempId = _uuid.v4();
    final localPath = filePath;

    await _db.insertJournal({
      'id': tempId,
      'content': '',
      'title': 'Audio Recording',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'audio_url': localPath,
      'is_pending_analysis': 1,
      'analysis_json': null,
      'last_synced_at': null,
    });

    await _syncRepo.enqueueMutation(
      entityType: 'journal',
      action: 'upload_audio',
      entityId: tempId,
      payload: {
        'localFilePath': localPath,
        'targetLanguage': targetLanguage,
        'moduleId': moduleId,
      },
    );

    return JournalEntry(
      id: tempId,
      content: '',
      title: 'Audio Recording',
      createdAt: DateTime.now(),
      audioUrl: localPath,
      isPending: true,
    );
  }

  Future<void> deleteEntry(String id) async {
    _logger.info('JournalService: Deleting entry $id locally');
    // Delete locally first, then sync
    // Note: Need to add delete to sync queue for full implementation
  }

  Future<void> analyzeEntry(String id) async {
    final isOnline = _ref.read(connectivityProvider);

    if (!isOnline) {
      _logger.warning(
        'JournalService: Cannot analyze entry while offline. Queuing analysis.',
      );
      await _syncRepo.enqueueMutation(
        entityType: 'journal',
        action: 'analyze',
        entityId: id,
        payload: {},
      );
      return;
    }

    _logger.info('JournalService: Starting analysis for $id');
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/analyze'),
      headers: await _getHeaders(),
      body: jsonEncode({'journalId': id}),
    );
    if (response.statusCode != 200) throw Exception('Failed to start analysis');
  }

  Future<List<String>> getSuggestedTopics(String targetLanguage) async {
    if (!_ref.read(connectivityProvider)) {
      return [];
    }

    final response = await http.get(
      Uri.parse(
        '${AppConstants.baseUrl}/api/user/suggested-topics?targetLanguage=$targetLanguage',
      ),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['topics'] ?? []);
    }
    return [];
  }

  Future<void> generateTopics(String targetLanguage) async {
    if (!_ref.read(connectivityProvider)) {
      return;
    }

    await http.get(
      Uri.parse(
        '${AppConstants.baseUrl}/api/user/generate-topics?targetLanguage=$targetLanguage',
      ),
      headers: await _getHeaders(),
    );
  }

  Future<WritingAids> getWritingAids(
    String topic,
    String targetLanguage,
  ) async {
    if (!_ref.read(connectivityProvider)) {
      throw Exception('Writing aids require internet connection');
    }

    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/journal/helpers'),
      headers: await _getHeaders(),
      body: jsonEncode({'topic': topic, 'targetLanguage': targetLanguage}),
    );

    if (response.statusCode == 200) {
      return WritingAids.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load writing aids');
  }

  Stream<List<JournalEntry>> watchJournals() {
    return _db.watchAllJournals().map(
      (journals) => journals.map((map) => _journalFromDb(map)).toList(),
    );
  }
}

final journalServiceProvider = Provider(
  (ref) => JournalService(
    ref,
    ref.watch(tokenServiceProvider(TokenType.auth)),
    ref.watch(databaseProvider),
    ref.watch(syncRepositoryProvider),
  ),
);
