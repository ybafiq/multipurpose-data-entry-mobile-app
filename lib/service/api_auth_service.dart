import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiAuthService {
  static const String baseUrl = 'https://example.com'; // Replace with your API base URL
  static const String _tokenKey = 'auth_token';
  static const String _tokenTypeKey = 'token_type';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _staffNoKey = 'staff_no';
  static const String _userPositionKey = 'user_position';
  static const String _userRoleKey = 'user_role';
  static const String _userStatusKey = 'user_status';

  // Initialize SharedPreferences
  static Future<void> init() async {
    await SharedPreferences.getInstance();
  }

  // Get stored token
  static Future<String> get getStorageToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) ?? '';
  }

  /// Login with Staff No and Password
  static Future<Map<String, dynamic>> login(
    String staffNo,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'staff_no': staffNo,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final userData = data['data']['user'];
          final token = data['data']['token'];
          final tokenType = data['data']['token_type'];

          // Save token and user data to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, token);
          await prefs.setString(_tokenTypeKey, tokenType);
          await prefs.setInt(_userIdKey, userData['id']);
          await prefs.setString(_userNameKey, userData['name'] ?? '');
          await prefs.setString(_staffNoKey, userData['staff_no'] ?? '');
          await prefs.setString(_userPositionKey, userData['position'] ?? '');
          await prefs.setString(_userRoleKey, userData['role'] ?? '');
          await prefs.setString(_userStatusKey, userData['status'] ?? '');

          return {
            'success': true,
            'message': 'Login successful',
            'staffNo': staffNo,
            'user': userData,
            'token': token,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Login failed',
          };
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Invalid Staff No or Password',
        };
      } else {
        return {
          'success': false,
          'message': 'Login failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Logout
  static Future<void> logout(BuildContext context) async {
    await init();

    final endpoint = Uri.parse('$baseUrl/api/logout');
    final token = await getAccessToken();
    final header = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      // Make logout request
      final response = await http.post(endpoint, headers: header);

      // Clear auth data but preserve other app settings
      await clearAuthData();

      // Log response status
      if (response.statusCode == 200) {
        debugPrint('Logout successful');
      } else {
        debugPrint(
            'Logout response: ${response.statusCode}. Cleared auth data anyway.');
      }
    } catch (e) {
      // Even if the server request fails, clear auth data
      debugPrint('Logout error: $e. Cleared auth data anyway.');
      await clearAuthData();
    }
  }

  /// Clear authentication data from SharedPreferences
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenTypeKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_staffNoKey);
    await prefs.remove(_userPositionKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userStatusKey);
  }

  /// Get stored access token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Get token type
  static Future<String?> getTokenType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenTypeKey);
  }

  /// Get stored user ID
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  /// Get stored user name
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  /// Get stored staff number
  static Future<String?> getStaffNo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_staffNoKey);
  }

  /// Get stored user position
  static Future<String?> getUserPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPositionKey);
  }

  /// Get stored user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  /// Get stored user status
  static Future<String?> getUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userStatusKey);
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Make authenticated API request
  static Future<http.Response> authenticatedRequest(
    String method,
    Uri url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final token = await getAccessToken();

    final requestHeaders = headers ?? {};
    requestHeaders['Content-Type'] = 'application/json';
    if (token != null) {
      requestHeaders['Authorization'] = 'Bearer $token';
    }

    http.Response response;

    if (method == 'GET') {
      response = await http.get(url, headers: requestHeaders);
    } else if (method == 'POST') {
      response = await http.post(
        url,
        headers: requestHeaders,
        body: body is String ? body : json.encode(body),
      );
    } else if (method == 'PUT') {
      response = await http.put(
        url,
        headers: requestHeaders,
        body: body is String ? body : json.encode(body),
      );
    } else if (method == 'DELETE') {
      response = await http.delete(url, headers: requestHeaders);
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    return response;
  }
}
