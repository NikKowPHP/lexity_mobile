import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:epub_pro/epub_pro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/book.dart';
import '../../database/repositories/sync_repository.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/logger_service.dart';
import '../../services/sync_service.dart';
import '../../utils/constants.dart';
import '../datasources/remote/book_remote_datasource.dart';
import '../datasources/local/book_local_datasource.dart';

class BookRepository {
  final Ref _ref;
  final BookRemoteDataSource _remoteDataSource;
  final BookLocalDataSource _localDataSource;
  final SyncRepository _syncRepo;
  late final LoggerService _logger;
  final _uuid = const Uuid();

  BookRepository(
    this._ref,
    this._remoteDataSource,
    this._localDataSource,
    this._syncRepo,
  ) {
    _logger = _ref.read(loggerProvider);
  }

  String getCoverProxyUrl(String bookId) {
    return '${AppConstants.baseUrl}/api/books/$bookId/cover';
  }

  Future<List<UserBook>> getBooks() async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final books = await _remoteDataSource.getBooks();
        for (final book in books) {
          await _localDataSource.upsertFromRemote(book as Map<String, dynamic>);
        }
        _logger.info(
          'BookRepository: Successfully fetched ${books.length} books from backend',
        );
        return books;
      } catch (e, st) {
        _logger.warning(
          'BookRepository: Failed to fetch from backend, falling back to local',
          e,
          st,
        );
      }
    }

    return _localDataSource.getAllBooks();
  }

  Future<List<UserBook>> syncBooks() async {
    _logger.info('BookRepository: Starting book sync from backend');
    final isOnline = _ref.read(connectivityProvider);

    if (!isOnline) {
      _logger.warning('BookRepository: Cannot sync, device is offline');
      return _localDataSource.getAllBooks();
    }

    try {
      final books = await _remoteDataSource.getBooks();
      for (final book in books) {
        await _localDataSource.upsertFromRemote(book as Map<String, dynamic>);
      }
      _logger.info(
        'BookRepository: Successfully fetched ${books.length} books from backend for sync',
      );
      return books;
    } catch (e, st) {
      _logger.error('BookRepository: Exception during book sync', e, st);
      return _localDataSource.getAllBooks();
    }
  }

  Future<UserBook?> getBook(String id) async {
    final isOnline = _ref.read(connectivityProvider);

    if (isOnline) {
      try {
        final book = await _remoteDataSource.getBook(id);
        await _localDataSource.upsertFromRemote(book as Map<String, dynamic>);
        return book;
      } catch (e, st) {
        _logger.warning(
          'BookRepository: Failed to fetch book $id from backend',
          e,
          st,
        );
      }
    }

    return _localDataSource.getBookById(id);
  }

  Future<void> updateProgress(String id, String cfi, double progressPct) async {
    _logger.info(
      'BookRepository: Updating progress for $id to $progressPct% locally',
    );

    await _localDataSource.updateProgress(id, cfi, progressPct);

    await _syncRepo.enqueueBookProgress(id, cfi, progressPct);

    _logger.info('BookRepository: Progress queued sync for $id');
    await _ref.read(syncServiceProvider).syncPendingMutations();
  }

  Future<void> updateLocations(String id, String locations) async {
    final isOnline = _ref.read(connectivityProvider);
    if (!isOnline) {
      _logger.warning(
        'BookRepository: Cannot update locations, device is offline',
      );
      return;
    }

    try {
      await _remoteDataSource.updateLocations(id, locations);
      _logger.info(
        'BookRepository: Locations updated successfully on server for $id',
      );

      final existingBook = await _localDataSource.getBookById(id);
      if (existingBook != null) {
        await _localDataSource.upsertFromRemote({
          ...existingBook as Map<String, dynamic>,
          'locations': locations,
        });
        _logger.info('BookRepository: Locations updated locally for $id');
      }
    } catch (e, st) {
      _logger.error('BookRepository: updateLocations error', e, st);
    }
  }

  Future<void> deleteBook(String id) async {
    _logger.info('BookRepository: Deleting book $id locally');

    await _localDataSource.deleteBook(id);

    await _syncRepo.enqueueBookDelete(id);

    _logger.info('BookRepository: Deletion queued for sync for $id');
  }

  Future<void> uploadBook(
    File file,
    String targetLanguage,
    String title,
  ) async {
    _logger.info('BookRepository: Starting EPUB upload sequence for "$title"');

    _logger.info('BookRepository: Extracting metadata and cover from EPUB');
    final bytes = await file.readAsBytes();

    final epubWithMeta = await _remoteDataSource.parseEpubWithIsolate(bytes);

    final author = epubWithMeta.author;
    final bookTitle = epubWithMeta.title;
    final coverImage = epubWithMeta.coverImage;
    final epubBook = epubWithMeta.book;

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
          _logger.info('BookRepository: Cover image found, preparing upload');
          final coverFilename =
              'cover-${DateTime.now().millisecondsSinceEpoch}.jpg';

          final coverUrlData = await _remoteDataSource.generateUploadUrl(
            coverFilename,
          );
          var coverSignedUrl = coverUrlData['signedUrl'] as String;
          coverStoragePath = coverUrlData['path'];

          if (coverSignedUrl.startsWith('/')) {
            coverSignedUrl = '${AppConstants.baseUrl}$coverSignedUrl';
          }

          final encodedCover = await _remoteDataSource.encodeCoverWithIsolate(
            coverImage,
          );

          await _remoteDataSource.uploadFile(
            coverSignedUrl,
            encodedCover,
            'image/jpeg',
          );
        } catch (e) {
          _logger.warning(
            'BookRepository: Error during cover extraction/upload',
            e,
          );
          coverStoragePath = null;
        }
      }

      _logger.info(
        'BookRepository: Requesting signed upload URL for $filename',
      );
      final uploadData = await _remoteDataSource.generateUploadUrl(filename);
      var signedUrl = uploadData['signedUrl'] as String;
      final storagePath = uploadData['path'];

      if (signedUrl.startsWith('/')) {
        signedUrl = '${AppConstants.baseUrl}$signedUrl';
      }

      _logger.info(
        'BookRepository: Uploading binary to storage path: $storagePath',
      );
      await _remoteDataSource.uploadFile(
        signedUrl,
        bytes,
        'application/epub+zip',
      );

      _logger.info('BookRepository: Registering book record in database');
      final book = await _remoteDataSource.registerBook(
        title: bookTitle,
        author: author,
        targetLanguage: targetLanguage,
        storagePath: storagePath,
        coverImageUrl: coverStoragePath,
      );
      await _localDataSource.upsertFromRemote(book as Map<String, dynamic>);
      _logger.info(
        'BookRepository: Upload and registration complete for "$bookTitle"',
      );
    } catch (e, st) {
      _logger.error('BookRepository: Exception in uploadBook', e, st);
      rethrow;
    }
  }

  Future<String?> _generateLocations(EpubBook epubBook) async {
    try {
      _logger.info('BookRepository: Generating locations from EPUB chapters');

      final chapters = epubBook.chapters;

      if (chapters.isEmpty) {
        _logger.warning('BookRepository: No chapters found in EPUB');
        return null;
      }

      int totalChars = 0;
      for (final chapter in chapters) {
        final content = chapter.htmlContent ?? '';
        totalChars += content.replaceAll(RegExp(r'\s+'), ' ').length;
      }

      if (totalChars == 0) {
        _logger.warning('BookRepository: No text content found in EPUB');
        return null;
      }

      const charsPerLocation = 1600;
      int currentChar = 0;
      int spineIndex = 0;
      final locations = <Map<String, dynamic>>[];

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

      _logger.info('BookRepository: Generated ${locations.length} locations');
      return jsonEncode(locations);
    } catch (e, st) {
      _logger.error('BookRepository: Error generating locations', e, st);
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
    _logger.info('BookRepository: Saving book locally for offline upload');

    final tempId = _uuid.v4();
    final localPath = file.path;

    String? coverLocalPath;
    if (coverImage != null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final coverFilename = 'cover-$tempId.jpg';
        final coverFile = File('${dir.path}/$coverFilename');

        final encoded = await Isolate.run(() => img.encodeJpg(coverImage));
        await coverFile.writeAsBytes(encoded);

        coverLocalPath = coverFile.path;
      } catch (e) {
        _logger.warning('BookRepository: Failed to save cover locally', e);
      }
    }

    final locations = await _generateLocations(epubBook);

    await _localDataSource.insertBook({
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

    _logger.info('BookRepository: Book saved locally, queued for upload');
  }

  Stream<List<UserBook>> watchBooks() {
    return _localDataSource.watchBooks();
  }
}

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(
    ref,
    ref.watch(bookRemoteDataSourceProvider),
    ref.watch(bookLocalDataSourceProvider),
    ref.watch(syncRepositoryProvider),
  );
});
