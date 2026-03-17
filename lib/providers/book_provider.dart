import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import '../services/logger_service.dart';

final booksStreamProvider = StreamProvider.autoDispose<List<UserBook>>((ref) {
  final service = ref.watch(bookServiceProvider);
  return service.watchBooks();
});

final booksProvider = booksStreamProvider;

final bookDetailProvider = FutureProvider.autoDispose.family<UserBook, String>((
  ref,
  id,
) async {
  final service = ref.watch(bookServiceProvider);
  final book = await service.getBook(id);
  if (book == null) {
    throw Exception('Book not found');
  }
  return book;
});

class BookNotifier extends StateNotifier<AsyncValue<void>> {
  final BookService _service;
  final LoggerService _logger;
  final Ref _ref;

  BookNotifier(this._service, this._logger, this._ref)
    : super(const AsyncValue.data(null));

  Future<void> uploadBook(
    File file,
    String targetLanguage,
    String title,
  ) async {
    _logger.info(
      'BookNotifier: Starting upload process for "$title" ($targetLanguage)',
    );
    state = const AsyncValue.loading();
    try {
      await _service.uploadBook(file, targetLanguage, title);
      state = const AsyncValue.data(null);
      _logger.info('BookNotifier: Upload successful');
    } catch (e, st) {
      _logger.error('BookNotifier: Upload failed', e, st);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteBook(String id) async {
    _logger.info('BookNotifier: Deleting book $id');
    try {
      await _service.deleteBook(id);
      _logger.info('BookNotifier: Deletion completed for $id');
    } catch (e, st) {
      _logger.error('BookNotifier: Deletion failed for $id', e, st);
    }
  }

  Future<void> updateProgress(String id, String cfi, double progressPct) async {
    _logger.info('BookNotifier: Updating progress for $id to $progressPct%');
    try {
      await _service.updateProgress(id, cfi, progressPct);
      _logger.info(
        'BookNotifier: Progress update successful for $id $cfi $progressPct',
      );
    } catch (e, st) {
      _logger.error('BookNotifier: Progress update failed for $id', e, st);
    }
  }
}

final bookNotifierProvider =
    StateNotifierProvider<BookNotifier, AsyncValue<void>>((ref) {
      return BookNotifier(
        ref.watch(bookServiceProvider),
        ref.read(loggerProvider),
        ref,
      );
    });
