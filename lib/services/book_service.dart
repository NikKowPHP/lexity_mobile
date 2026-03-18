import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:epub_pro/epub_pro.dart';
import 'package:image/image.dart' as img;
import '../models/book.dart';
import '../utils/constants.dart';
import '../database/app_database.dart';
import '../database/repositories/sync_repository.dart';
import '../providers/connectivity_provider.dart';
import 'logger_service.dart';
import 'sync_service.dart';
import '../network/api_client.dart';

class BookService {
  final ApiClient _client;
  final AppDatabase _db;
  final SyncRepository _syncRepo;
  final Ref _ref;
  late final LoggerService _logger;
  final Uuid _uuid = const Uuid();

  BookService(this._client, this._db, this._syncRepo, this._ref, this._logger);

  String getCoverProxyUrl(String bookId) {
    return '${AppConstants.baseUrl}/api/books/$bookId/cover';
  }

  Future<List<UserBook>> getBooks() async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await _client.get('/api/books');

        if (response.statusCode == 200) {
          final List data = response.data;
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

    return getLocalBooks();
  }

  Future<List<UserBook>> syncBooks() async {
    _logger.info('BookService: Starting book sync from backend');
    final isOnline = _ref.read(connectivityProvider);

    if (!isOnline) {
      _logger.warning('BookService: Cannot sync, device is offline');
      return getLocalBooks();
    }

    try {
      final response = await _client.get('/api/books');

      if (response.statusCode == 200) {
        final List data = response.data;
        _logger.info(
          'BookService: Successfully fetched ${data.length} books from backend for sync',
        );

        for (final item in data) {
          await _upsertBookLocal(item);
        }

        return data.map((e) => UserBook.fromJson(e)).toList();
      } else {
        _logger.error(
          'BookService: Failed to sync books. Status: ${response.statusCode}',
        );
        return getLocalBooks();
      }
    } catch (e, st) {
      _logger.error('BookService: Exception during book sync', e, st);
      return getLocalBooks();
    }
  }

  Future<List<UserBook>> getLocalBooks() async {
    final books = await _db.getAllBooks();
    return books.map((map) => _userBookFromDb(map)).toList();
  }

  Future<UserBook?> getBook(String id) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final response = await _client.get('/api/books/$id');

        if (response.statusCode == 200) {
          final data = response.data;
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

    _logger.info('BookService: Progress queued sync for $id');
    await _ref.read(syncServiceProvider).syncPendingMutations();
  }

  Future<void> updateLocations(String id, String locations) async {
    final isOnline = _ref.read(connectivityProvider);
    if (!isOnline) {
      _logger.warning(
        'BookService: Cannot update locations, device is offline',
      );
      return;
    }

    try {
      final response = await _client.patch(
        '/api/books/$id',
        data: {'locations': locations},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save locations to server');
      }

      _logger.info(
        'BookService: Locations updated successfully on server for $id',
      );

      final existingBook = await _db.getBookById(id);
      if (existingBook != null) {
        await _db.insertBook({...existingBook, 'locations': locations});
        _logger.info('BookService: Locations updated locally for $id');
      }
    } catch (e, st) {
      _logger.error('BookService: updateLocations error', e, st);
    }
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

    _logger.info('BookService: Extracting metadata and cover from EPUB');
    final bytes = await file.readAsBytes();
    
    // OFFLOAD EPUB PARSING
    final epubBook = await Isolate.run(() => EpubReader.readBook(bytes));
    
    final author = epubBook.author ?? "Unknown";
    final bookTitle = epubBook.title ?? title;
    final coverImage = epubBook.coverImage;

    final isOnline = _ref.read(connectivityProvider);

    if (!isOnline) {
      await _uploadBookOffline(
        file,
        targetLanguage,
        bookTitle,
        author,
        coverImage,
        epubBook,
      );
      return;
    }

    try {
      final filename = file.path.split('/').last;
      String? coverStoragePath;

      if (coverImage != null) {
        try {
          _logger.info('BookService: Cover image found, preparing upload');
          final coverFilename =
              'cover-${DateTime.now().millisecondsSinceEpoch}.jpg';

          final signedResponse = await _client.get(
            '/api/books/generate-upload-url',
            queryParameters: {'filename': coverFilename},
          );

          if (signedResponse.statusCode == 200) {
            final coverUrlData = signedResponse.data;
            var coverSignedUrl = coverUrlData['signedUrl'] as String;
            coverStoragePath = coverUrlData['path'];

            if (coverSignedUrl.startsWith('/')) {
              coverSignedUrl = '${AppConstants.baseUrl}$coverSignedUrl';
            }

            // OFFLOAD IMAGE ENCODING
            final encodedCover = await Isolate.run(() => img.encodeJpg(coverImage));

            final uploadRes = await http.put(
              Uri.parse(coverSignedUrl),
              headers: {'Content-Type': 'image/jpeg'},
              body: encodedCover,
            );

            if (uploadRes.statusCode != 200) {
              _logger.warning(
                'BookService: Cover upload failed, proceeding without it',
              );
              coverStoragePath = null;
            }
          }
        } catch (e) {
          _logger.warning(
            'BookService: Error during cover extraction/upload',
            e,
          );
          coverStoragePath = null;
        }
      }

      _logger.info('BookService: Requesting signed upload URL for $filename');
      final uploadUrlResponse = await _client.get(
        '/api/books/generate-upload-url',
        queryParameters: {'filename': filename},
      );

      if (uploadUrlResponse.statusCode != 200) {
        _logger.error(
          'BookService: Failed to get upload URL. Status: ${uploadUrlResponse.statusCode}',
        );
        throw Exception('Failed to get upload URL');
      }

      final uploadData = uploadUrlResponse.data;
      var signedUrl = uploadData['signedUrl'] as String;
      final storagePath = uploadData['path'];

      if (signedUrl.startsWith('/')) {
        signedUrl = '${AppConstants.baseUrl}$signedUrl';
      }

      _logger.info(
        'BookService: Uploading binary to storage path: $storagePath',
      );
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
      final dbRes = await _client.post(
        '/api/books',
        data: {
          'title': bookTitle,
          'author': author,
          'targetLanguage': targetLanguage,
          'storagePath': storagePath,
          'coverImageUrl': coverStoragePath,
        },
      );

      if (dbRes.statusCode == 200 || dbRes.statusCode == 201) {
        final data = dbRes.data;
        await _upsertBookLocal(data);
        _logger.info(
          'BookService: Upload and registration complete for "$bookTitle"',
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

  Future<String?> _generateLocations(EpubBook epubBook) async {
    try {
      _logger.info('BookService: Generating locations from EPUB chapters');

      final locations = <Map<String, dynamic>>[];
      final chapters = epubBook.chapters;

      if (chapters.isEmpty) {
        _logger.warning('BookService: No chapters found in EPUB');
        return null;
      }

      int totalChars = 0;
      for (final chapter in chapters) {
        final content = chapter.htmlContent ?? '';
        totalChars += content.replaceAll(RegExp(r'\s+'), ' ').length;
      }

      if (totalChars == 0) {
        _logger.warning('BookService: No text content found in EPUB');
        return null;
      }

      const charsPerLocation = 1600;
      int currentChar = 0;
      int spineIndex = 0;

      for (final chapter in chapters) {
        final content = chapter.htmlContent ?? '';
        final plainText = content.replaceAll(RegExp(r'\s+'), ' ');

        int offset = 0;
        while (offset < plainText.length) {
          final cfi = _generateCfi(spineIndex, offset);
          final percentage = currentChar / totalChars;

          locations.add({
            'cfi': cfi,
            'percentage': percentage,
            'location': locations.length + 1,
          });

          offset += charsPerLocation;
          currentChar += charsPerLocation;

          if (currentChar > totalChars) break;
        }
        spineIndex++;
      }

      if (locations.isEmpty) {
        return null;
      }

      _logger.info('BookService: Generated ${locations.length} locations');
      return jsonEncode(locations);
    } catch (e, st) {
      _logger.error('BookService: Error generating locations', e, st);
      return null;
    }
  }

  String _generateCfi(int spineIndex, int offset) {
    final part = (offset ~/ 2) + 1;
    return 'epubcfi(/6/$spineIndex/4/$part)';
  }

  Future<void> _uploadBookOffline(
    File file,
    String targetLanguage,
    String title,
    String author,
    img.Image? coverImage,
    EpubBook epubBook,
  ) async {
    _logger.info('BookService: Saving book locally for offline upload');

    final tempId = _uuid.v4();
    final localPath = file.path;

    String? coverLocalPath;
    if (coverImage != null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final coverFilename = 'cover-$tempId.jpg';
        final coverFile = File('${dir.path}/$coverFilename');
        
        // OFFLOAD IMAGE ENCODING
        final encoded = await Isolate.run(() => img.encodeJpg(coverImage));
        await coverFile.writeAsBytes(encoded);
        
        coverLocalPath = coverFile.path;
      } catch (e) {
        _logger.warning('BookService: Failed to save cover locally', e);
      }
    }

    final locations = await _generateLocations(epubBook);

    await _db.insertBook({
      'id': tempId,
      'title': title,
      'author': author,
      'target_language': targetLanguage,
      'storage_path': localPath,
      'cover_image_url': coverLocalPath,
      'current_cfi': null,
      'progress_pct': 0.0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'signed_url': null,
      'locations': locations,
      'last_synced_at': null,
    });

    await _syncRepo.enqueueMutation(
      entityType: 'book',
      action: 'upload_binary',
      entityId: tempId,
      payload: {
        'title': title,
        'author': author,
        'targetLanguage': targetLanguage,
        'localFilePath': localPath,
      },
    );

    _logger.info('BookService: Book saved locally, queued for upload');
  }

  Stream<List<UserBook>> watchBooks() {
    return _db.watchAllBooks().map(
      (books) => books.map((map) => _userBookFromDb(map)).toList(),
    );
  }
}

final bookServiceProvider = Provider(
  (ref) => BookService(
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider),
    ref.watch(syncRepositoryProvider),
    ref,
    ref.read(loggerProvider),
  ),
);
