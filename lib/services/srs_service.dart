import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import '../models/srs_item.dart';
import 'logger_service.dart';

class SrsService {
  final Ref _ref;
  final AuthService _auth;
  late final LoggerService _logger;

  SrsService(this._ref, this._auth) {
    _logger = _ref.read(loggerProvider);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<SrsItem>> fetchDeck(String language) async {
    _logger.info('SrsService: Fetching SRS deck for language: $language');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/srs/deck?targetLanguage=$language'),
        headers: await _getHeaders(),
      );

      _logger.debug('SrsService: fetchDeck response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _logger.info('SrsService: Deck fetched successfully, found ${data.length} items');
        return data.map((item) => SrsItem.fromJson(item)).toList();
      }

      final errorMsg = jsonDecode(response.body)['error'] ?? 'Failed to load deck';
      _logger.warning('SrsService: Deck fetch failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('SrsService: Error during fetchDeck', e, stackTrace);
      rethrow;
    }
  }

  Future<void> reviewItem(String id, int quality) async {
    _logger.info('SrsService: Submitting review for item: $id, quality: $quality');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/srs/review'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'srsItemId': id,
          'quality': quality,
        }),
      );

      _logger.debug('SrsService: reviewItem response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _logger.info('SrsService: Review submitted successfully');
        return;
      }

      final errorMsg = jsonDecode(response.body)['error'] ?? 'Failed to submit review';
      _logger.warning('SrsService: Review submission failed. Reason: $errorMsg');
      throw Exception(errorMsg);
    } catch (e, stackTrace) {
      _logger.error('SrsService: Error during reviewItem', e, stackTrace);
      rethrow;
    }
  }
}

final srsServiceProvider = Provider((ref) => SrsService(ref, ref.watch(authServiceProvider)));
