import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../utils/constants.dart';
import '../database/app_database.dart';
import '../database/repositories/sync_repository.dart';
import '../providers/connectivity_provider.dart';
import 'token_service.dart';
import 'logger_service.dart';

class BookService {
  final TokenService _authTokenService;
  final AppDatabase _db;
  final SyncRepository _syncRepo;
  final Ref _ref;
  late final LoggerService _logger;

  BookService(
    this._authTokenService,
    this._db,
    this._syncRepo,
    this._ref,
    this._logger,
  );

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<UserBook>> getBooks() async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('${AppConstants.baseUrl}/api/books'),
          headers: await _getHeaders(),
        );

        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          _logger.info(
            'BookService: Successfully fetched ${data.length} books from backend',
          );

          for (final item in data) {
            await _upsertBookLocal(item);
          }

          return data.map((e) => UserBook.fromJson(e)).toList();
        }
      } catch (e, st) {
        _logger.warning(
          'BookService: Failed to fetch from backend, falling back to local',
          e,
          st,
        );
      }
    }

    return _getLocalBooks();
  }

  Future<List<UserBook>> _getLocalBooks() async {
    final books = await _db.getAllBooks();
    return books.map((map) => _userBookFromDb(map)).toList();
  }

  Future<UserBook?> getBook(String id) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('${AppConstants.baseUrl}/api/books/$id'),
          headers: await _getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          await _upsertBookLocal(data);
          return UserBook.fromJson(data);
        }
      } catch (e, st) {
        _logger.warning(
          'BookService: Failed to fetch book $id from backend',
          e,
          st,
        );
      }
    }

    final localBook = await _db.getBookById(id);
    return localBook != null ? _userBookFromDb(localBook) : null;
  }

  Future<void> _upsertBookLocal(Map<String, dynamic> data) async {
    await _db.insertBook({
      'id': data['id'],
      'title': data['title'] ?? 'Unknown Title',
      'author': data['author'],
      'target_language': data['targetLanguage'] ?? 'spanish',
      'storage_path': data['storagePath'] ?? '',
      'cover_image_url': data['coverImageUrl'],
      'current_cfi': data['currentCfi'],
      'progress_pct': (data['progressPct'] ?? 0).toDouble(),
      'created_at': DateTime.parse(data['createdAt']).millisecondsSinceEpoch,
      'signed_url': data['signedUrl']?.startsWith('/') == true
          ? '${AppConstants.baseUrl}${data['signedUrl']}'
          : data['signedUrl'],
      'locations': data['locations'],
      'last_synced_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  UserBook _userBookFromDb(Map<String, dynamic> map) {
    return UserBook(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      targetLanguage: map['target_language'] as String,
      storagePath: map['storage_path'] as String,
      coverImageUrl: map['cover_image_url'] as String?,
      currentCfi: map['current_cfi'] as String?,
      progressPct: (map['progress_pct'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      signedUrl: map['signed_url'] as String?,
      locations: map['locations'] as String?,
    );
  }

  Future<void> updateProgress(String id, String cfi, double progressPct) async {
    _logger.info(
      'BookService: Updating progress for $id to $progressPct% locally',
    );

    await _db.updateBookProgress(id, cfi, progressPct);

    await _syncRepo.enqueueBookProgress(id, cfi, progressPct);

    _logger.info('BookService: Progress queued for sync for $id');
  }

  Future<void> deleteBook(String id) async {
    _logger.info('BookService: Deleting book $id locally');

    await _db.deleteBook(id);

    await _syncRepo.enqueueBookDelete(id);

    _logger.info('BookService: Deletion queued for sync for $id');
  }

  Future<void> uploadBook(
    File file,
    String targetLanguage,
    String title,
  ) async {
    _logger.info('BookService: Starting EPUB upload sequence for "$title"');
    try {
      final filename = file.path.split('/').last;

      _logger.info('BookService: Requesting signed upload URL for $filename');
      final uploadUrlResponse = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/api/books/generate-upload-url?filename=$filename',
        ),
        headers: await _getHeaders(),
      );

      if (uploadUrlResponse.statusCode != 200) {
        _logger.error(
          'BookService: Failed to get upload URL. Status: ${uploadUrlResponse.statusCode}',
        );
        throw Exception('Failed to get upload URL');
      }

      final uploadData = jsonDecode(uploadUrlResponse.body);
      var signedUrl = uploadData['signedUrl'] as String;
      final storagePath = uploadData['path'];

      if (signedUrl.startsWith('/')) {
        signedUrl = '${AppConstants.baseUrl}$signedUrl';
      }

      _logger.info(
        'BookService: Uploading binary to storage path: $storagePath',
      );
      final bytes = await file.readAsBytes();
      final uploadRes = await http.put(
        Uri.parse(signedUrl),
        headers: {'Content-Type': 'application/epub+zip'},
        body: bytes,
      );

      if (uploadRes.statusCode != 200) {
        _logger.error(
          'BookService: Storage upload failed. Status: ${uploadRes.statusCode}',
        );
        throw Exception('Failed to upload file to storage');
      }

      _logger.info('BookService: Registering book record in database');
      final dbRes = await http.post(
        Uri.parse('${AppConstants.baseUrl}/api/books'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'title': title,
          'author': 'Unknown',
          'targetLanguage': targetLanguage,
          'storagePath': storagePath,
        }),
      );

      if (dbRes.statusCode == 200 || dbRes.statusCode == 201) {
        final data = jsonDecode(dbRes.body);
        await _upsertBookLocal(data);
        _logger.info(
          'BookService: Upload and registration complete for "$title"',
        );
        return;
      }
      _logger.error(
        'BookService: Database registration failed. Status: ${dbRes.statusCode}',
      );
      throw Exception('Failed to save book to database');
    } catch (e, st) {
      _logger.error('BookService: Exception in uploadBook', e, st);
      rethrow;
    }
  }

  Stream<List<UserBook>> watchBooks() {
    return _db.watchAllBooks().map(
      (books) => books.map((map) => _userBookFromDb(map)).toList(),
    );
  }
}

final bookServiceProvider = Provider(
  (ref) => BookService(
    ref.watch(tokenServiceProvider(TokenType.auth)),
    ref.watch(databaseProvider),
    ref.watch(syncRepositoryProvider),
    ref,
    ref.read(loggerProvider),
  ),
);
