import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../utils/constants.dart';
import 'token_service.dart';
import 'logger_service.dart';

class BookService {
  final TokenService _authTokenService;
  late final LoggerService _logger;

  BookService(this._authTokenService, this._logger);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authTokenService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<UserBook>> getBooks() async {
    _logger.info('BookService: Fetching books');
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/books'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => UserBook.fromJson(e)).toList();
    }
    throw Exception('Failed to load books');
  }

  Future<UserBook> getBook(String id) async {
    _logger.info('BookService: Fetching book details for $id');
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/books/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return UserBook.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load book');
  }

  Future<void> updateProgress(String id, String cfi, double progressPct) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/api/books/$id/progress'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'currentCfi': cfi, 
        'progressPct': double.parse(progressPct.toStringAsFixed(2)),
      }),
    );
    
    if (response.statusCode != 200) {
      _logger.warning('Failed to update progress for book $id: ${response.statusCode}');
    }
  }

  Future<void> deleteBook(String id) async {
    _logger.info('BookService: Deleting book $id');
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/api/books/$id'),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete book');
    }
  }

  Future<void> uploadBook(File file, String targetLanguage, String title) async {
    _logger.info('BookService: Uploading new EPUB book');
    final filename = file.path.split('/').last;
    
    // 1. Get signed upload URL
    final uploadUrlResponse = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/books/generate-upload-url?filename=$filename'),
      headers: await _getHeaders(),
    );
    
    if (uploadUrlResponse.statusCode != 200) throw Exception('Failed to get upload URL');
    
    final uploadData = jsonDecode(uploadUrlResponse.body);
    final signedUrl = uploadData['signedUrl'];
    final storagePath = uploadData['path'];

    // 2. Put file to Supabase storage
    final bytes = await file.readAsBytes();
    final uploadRes = await http.put(
      Uri.parse(signedUrl),
      headers: {'Content-Type': 'application/epub+zip'},
      body: bytes,
    );

    if (uploadRes.statusCode != 200) throw Exception('Failed to upload file to storage');

    // 3. Register book record in API
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

    if (dbRes.statusCode != 200) throw Exception('Failed to save book to database');
  }
}

final bookServiceProvider = Provider((ref) => 
  BookService(ref.watch(tokenServiceProvider(TokenType.auth)), ref.read(loggerProvider))
);
