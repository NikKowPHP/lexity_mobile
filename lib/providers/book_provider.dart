import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/book_service.dart';

final booksProvider = FutureProvider.autoDispose<List<UserBook>>((ref) async {
  final service = ref.watch(bookServiceProvider);
  return service.getBooks();
});

final bookDetailProvider = FutureProvider.autoDispose.family<UserBook, String>((ref, id) async {
  final service = ref.watch(bookServiceProvider);
  return service.getBook(id);
});

class BookNotifier extends StateNotifier<AsyncValue<void>> {
  final BookService _service;
  final Ref _ref;

  BookNotifier(this._service, this._ref) : super(const AsyncValue.data(null));

  Future<void> uploadBook(File file, String targetLanguage, String title) async {
    state = const AsyncValue.loading();
    try {
      await _service.uploadBook(file, targetLanguage, title);
      _ref.invalidate(booksProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteBook(String id) async {
    try {
      await _service.deleteBook(id);
      _ref.invalidate(booksProvider);
    } catch (e) {
      // handle error gracefully
    }
  }

  Future<void> updateProgress(String id, String cfi, double progressPct) async {
    try {
      await _service.updateProgress(id, cfi, progressPct);
    } catch (e) {
      // Don't interrupt reading if saving progress fails silently
    }
  }
}

final bookNotifierProvider = StateNotifierProvider<BookNotifier, AsyncValue<void>>((ref) {
  return BookNotifier(ref.watch(bookServiceProvider), ref);
});
