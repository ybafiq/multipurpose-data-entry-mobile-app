import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ApiRecordService {
  // ===== CONSTANTS =====
  static const String baseUrl = 'https://demo-api.example.com'; // Demo API endpoint

  // ===== API DATA PREPARATION =====

  /// Prepare API entry data for submission
  static Map<String, dynamic> prepareApiEntry({
    required int? trialId,
    required int? plotId,
    required int? treeNumber,
    required DateTime measurementDate,
    required DateTime measurementTime,
    required double weight,
    required int bunches,
  }) {
    return {
      "trial_id": trialId,
      "plot_id": plotId,
      "tree_number": treeNumber,
      "measurement_date": DateFormat('yyyy-MM-dd').format(measurementDate),
      "measurement_time": DateFormat('HH:mm:ss').format(measurementTime),
      "remark": "Mobile data recording from worker",
      "parameters": [
        {
          "parameter_id": 1,
          "value": weight,
          "remark": "Bunch Weight measured in kg"
        },
        {
          "parameter_id": 2,
          "value": bunches,
          "remark": "Number of bunches counted"
        }
      ]
    };
  }

  // ===== TOKEN MANAGEMENT =====

  /// Get stored authentication token
  static Future<String> get getStorageToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  /// Get stored token type
  static Future<String> get getTokenType async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token_type') ?? '';
  }

  // ===== RECORD API METHODS =====

  /// Submit a record entry to the API
  static Future<Map<String, dynamic>> submitRecord(Map<String, dynamic> record) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/store-data-recording'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
        body: json.encode(record),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return data;
        } else {
          String errorMessage = data['message'] ?? 'Failed to submit record';
          
          if (data.containsKey('errors')) {
            final errors = data['errors'];
            if (errors is Map) {
              // Handle Laravel-style validation errors: {"field": ["error1", "error2"]}
              List<String> detailedErrors = [];
              errors.forEach((field, fieldErrors) {
                if (fieldErrors is List) {
                  detailedErrors.addAll(fieldErrors.map((e) => "$field: $e"));
                }
              });
              if (detailedErrors.isNotEmpty) {
                errorMessage += '\n\nDetailed errors:\n${detailedErrors.join('\n')}';
              }
            } else if (errors is List) {
              // Handle list-style errors (fallback)
              String detailedErrors = errors.map((e) => "${e['parameter_name']}: ${e['message']}").join('\n');
              errorMessage += '\n\nDetailed errors:\n$detailedErrors';
            }
          }
          
          throw Exception(errorMessage);
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else if (response.statusCode == 422) {
        print('API returned 422. Response body: ${response.body}');
        final data = json.decode(response.body);
        String errorMessage = data['message'] ?? 'Validation failed';
        
        if (data.containsKey('errors')) {
          final errors = data['errors'];
          if (errors is Map) {
            // Handle Laravel-style validation errors: {"field": ["error1", "error2"]}
            List<String> detailedErrors = [];
            errors.forEach((field, fieldErrors) {
              if (fieldErrors is List) {
                detailedErrors.addAll(fieldErrors.map((e) => "$field: $e"));
              }
            });
            if (detailedErrors.isNotEmpty) {
              errorMessage += '\n\nDetailed errors:\n${detailedErrors.join('\n')}';
            }
          } else if (errors is List) {
            // Handle list-style errors (fallback)
            String detailedErrors = errors.map((e) => "${e['parameter_name']}: ${e['message']}").join('\n');
            errorMessage += '\n\nDetailed errors:\n$detailedErrors';
          }
        }
        
        throw Exception(errorMessage);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        throw Exception('Connection timeout. Please check your internet connection.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Sync multiple records to the API
  static Future<List<Map<String, dynamic>>> syncRecords(List<Map<String, dynamic>> records) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/sync-records'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
        body: json.encode({'records': records}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final syncedRecords = data['synced_records'] as List<dynamic>? ?? [];
          return syncedRecords.map((r) => r as Map<String, dynamic>).toList();
        } else {
          String errorMessage = data['message'] ?? 'Failed to sync records';
          
          if (data.containsKey('errors')) {
            final errors = data['errors'];
            if (errors is Map) {
              // Handle Laravel-style validation errors: {"field": ["error1", "error2"]}
              List<String> detailedErrors = [];
              errors.forEach((field, fieldErrors) {
                if (fieldErrors is List) {
                  detailedErrors.addAll(fieldErrors.map((e) => "$field: $e"));
                }
              });
              if (detailedErrors.isNotEmpty) {
                errorMessage += '\n\nDetailed errors:\n${detailedErrors.join('\n')}';
              }
            } else if (errors is List) {
              // Handle list-style errors (fallback)
              String detailedErrors = errors.map((e) => "${e['parameter_name']}: ${e['message']}").join('\n');
              errorMessage += '\n\nDetailed errors:\n$detailedErrors';
            }
          }
          
          throw Exception(errorMessage);
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else if (response.statusCode == 422) {
        print('API returned 422. Response body: ${response.body}');
        final data = json.decode(response.body);
        String errorMessage = data['message'] ?? 'Validation failed';
        
        if (data.containsKey('errors')) {
          final errors = data['errors'];
          if (errors is Map) {
            // Handle Laravel-style validation errors: {"field": ["error1", "error2"]}
            List<String> detailedErrors = [];
            errors.forEach((field, fieldErrors) {
              if (fieldErrors is List) {
                detailedErrors.addAll(fieldErrors.map((e) => "$field: $e"));
              }
            });
            if (detailedErrors.isNotEmpty) {
              errorMessage += '\n\nDetailed errors:\n${detailedErrors.join('\n')}';
            }
          } else if (errors is List) {
            // Handle list-style errors (fallback)
            String detailedErrors = errors.map((e) => "${e['parameter_name']}: ${e['message']}").join('\n');
            errorMessage += '\n\nDetailed errors:\n$detailedErrors';
          }
        }
        
        throw Exception(errorMessage);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        throw Exception('Connection timeout. Please check your internet connection.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Fetch records for a specific worker
  static Future<List<Map<String, dynamic>>> getRecords(String workerId) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/records?worker_id=$workerId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final records = data['data'] as List<dynamic>;
          return records.map((record) => record as Map<String, dynamic>).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch records');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        throw Exception('Connection timeout. Please check your internet connection.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }
}
