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
    _logger.info('BookService: Fetching books list from backend');
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/books'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _logger.info('BookService: Successfully fetched ${data.length} books');
        return data.map((e) => UserBook.fromJson(e)).toList();
      }
      _logger.error('BookService: Failed to fetch books. Status: ${response.statusCode}');
      throw Exception('Failed to load books');
    } catch (e, st) {
      _logger.error('BookService: Exception in getBooks', e, st);
      rethrow;
    }
  }

  Future<UserBook> getBook(String id) async {
    _logger.info('BookService: Fetching book details for ID: $id');
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/books/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('BookService: Successfully fetched details for "${data['title']}"');
        return UserBook.fromJson(data);
      }
      _logger.error('BookService: Failed to fetch book $id. Status: ${response.statusCode}');
      throw Exception('Failed to load book');
    } catch (e, st) {
      _logger.error('BookService: Exception in getBook $id', e, st);
      rethrow;
    }
  }

  Future<void> updateProgress(String id, String cfi, double progressPct) async {
    _logger.info('BookService: Requesting progress update for $id to $progressPct% ($cfi)');
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/api/books/$id/progress'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'currentCfi': cfi, 
          'progressPct': progressPct,
        }),
      );
      
      if (response.statusCode == 200) {
        _logger.info('BookService: Progress update confirmed by server for $id');
        return;
      }
      _logger.warning('BookService: Server rejected progress update for $id. Status: ${response.statusCode}');
      throw Exception('Failed to update progress on server');
    } catch (e, st) {
      _logger.error('BookService: Exception in updateProgress for $id', e, st);
      rethrow;
    }
  }

  Future<void> deleteBook(String id) async {
    _logger.info('BookService: Requesting deletion of book $id');
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/api/books/$id'),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.info('BookService: Deletion successful for $id');
        return;
      }
      _logger.error('BookService: Failed to delete book $id. Status: ${response.statusCode}');
      throw Exception('Failed to delete book');
    } catch (e, st) {
      _logger.error('BookService: Exception in deleteBook $id', e, st);
      rethrow;
    }
  }

  Future<void> uploadBook(File file, String targetLanguage, String title) async {
    _logger.info('BookService: Starting EPUB upload sequence for "$title"');
    try {
      final filename = file.path.split('/').last;
      
      _logger.info('BookService: Requesting signed upload URL for $filename');
      final uploadUrlResponse = await http.get(
        Uri.parse('${AppConstants.baseUrl}/api/books/generate-upload-url?filename=$filename'),
        headers: await _getHeaders(),
      );
      
      if (uploadUrlResponse.statusCode != 200) {
        _logger.error('BookService: Failed to get upload URL. Status: ${uploadUrlResponse.statusCode}');
        throw Exception('Failed to get upload URL');
      }
      
      final uploadData = jsonDecode(uploadUrlResponse.body);
      final signedUrl = uploadData['signedUrl'];
      final storagePath = uploadData['path'];

      _logger.info('BookService: Uploading binary to storage path: $storagePath');
      final bytes = await file.readAsBytes();
      final uploadRes = await http.put(
        Uri.parse(signedUrl),
        headers: {'Content-Type': 'application/epub+zip'},
        body: bytes,
      );

      if (uploadRes.statusCode != 200) {
        _logger.error('BookService: Storage upload failed. Status: ${uploadRes.statusCode}');
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
        _logger.info('BookService: Upload and registration complete for "$title"');
        return;
      }
      _logger.error('BookService: Database registration failed. Status: ${dbRes.statusCode}');
      throw Exception('Failed to save book to database');
    } catch (e, st) {
      _logger.error('BookService: Exception in uploadBook', e, st);
      rethrow;
    }
  }
}

final bookServiceProvider = Provider((ref) => 
  BookService(ref.watch(tokenServiceProvider(TokenType.auth)), ref.read(loggerProvider))
);
