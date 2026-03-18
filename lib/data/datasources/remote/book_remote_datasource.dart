import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:epub_pro/epub_pro.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../../../network/api_client.dart';
import '../../../models/book.dart';

class BookRemoteDataSource {
  final ApiClient _client;

  BookRemoteDataSource(this._client);

  Future<List<UserBook>> getBooks() async {
    final response = await _client.get('/api/books');
    if (response.statusCode == 200) {
      final List data = response.data;
      return data.map((e) => UserBook.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch books');
  }

  Future<UserBook> getBook(String id) async {
    final response = await _client.get('/api/books/$id');
    if (response.statusCode == 200) {
      return UserBook.fromJson(response.data);
    }
    throw Exception('Failed to fetch book');
  }

  Future<Map<String, dynamic>> generateUploadUrl(String filename) async {
    final response = await _client.get(
      '/api/books/generate-upload-url',
      queryParameters: {'filename': filename},
    );
    if (response.statusCode == 200) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Failed to generate upload URL');
  }

  Future<void> uploadFile(
    String signedUrl,
    List<int> bytes,
    String contentType,
  ) async {
    final response = await _client.dio.put(
      signedUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {'Content-Type': contentType, 'Content-Length': bytes.length},
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to upload file');
    }
  }

  Future<UserBook> registerBook({
    required String title,
    required String author,
    required String targetLanguage,
    required String storagePath,
    String? coverImageUrl,
  }) async {
    final response = await _client.post(
      '/api/books',
      data: {
        'title': title,
        'author': author,
        'targetLanguage': targetLanguage,
        'storagePath': storagePath,
        'coverImageUrl': coverImageUrl,
      },
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return UserBook.fromJson(response.data);
    }
    throw Exception('Failed to save book to database');
  }

  Future<void> updateLocations(String id, String locations) async {
    final response = await _client.patch(
      '/api/books/$id',
      data: {'locations': locations},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save locations to server');
    }
  }

  Future<EpubBookWithMeta> parseEpubWithIsolate(List<int> bytes) async {
    final result = await Isolate.run(() async {
      final book = await EpubReader.readBook(bytes);
      return EpubBookWithMeta(
        book: book,
        author: book.author ?? "Unknown",
        title: book.title ?? "Unknown Title",
        coverImage: book.coverImage,
      );
    });
    return result;
  }

  Future<List<int>> encodeCoverWithIsolate(img.Image coverImage) async {
    return Isolate.run(() => img.encodeJpg(coverImage));
  }
}

class EpubBookWithMeta {
  final EpubBook book;
  final String author;
  final String title;
  final img.Image? coverImage;

  EpubBookWithMeta({
    required this.book,
    required this.author,
    required this.title,
    this.coverImage,
  });
}

final bookRemoteDataSourceProvider = Provider<BookRemoteDataSource>((ref) {
  return BookRemoteDataSource(ref.watch(apiClientProvider));
});
