// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Change this based on your device
final String baseUrl = Platform.isAndroid
    ? 'http://10.0.2.2:3000'
    : 'http://localhost:3000';

class AuthService {
  final Ref ref;
  AuthService(this.ref);

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Assuming your API returns session.access_token or similar
        // Adjust parsing based on exact API response structure in route.ts
        if (data['session'] != null &&
            data['session']['access_token'] != null) {
          await saveToken(data['session']['access_token']);
          return true;
        }
      }
      throw Exception(jsonDecode(response.body)['error'] ?? 'Login failed');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> signUp(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['session'] != null &&
            data['session']['access_token'] != null) {
          await saveToken(data['session']['access_token']);
          return true;
        }
      }
      throw Exception(jsonDecode(response.body)['error'] ?? 'Signup failed');
    } catch (e) {
      rethrow;
    }
  }
}

final authServiceProvider = Provider((ref) => AuthService(ref));
