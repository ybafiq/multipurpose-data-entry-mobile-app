import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiTrialService {
  // ===== CONSTANTS =====
  static const String baseUrl = 'https://demo-api.example.com'; // Demo API endpoint

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

  // ===== TRIAL API METHODS =====

  /// Fetch all available trials
  static Future<List<Map<String, dynamic>>> getTrials() async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/fetch-trial'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final trials = data['data'] as List<dynamic>;
          return trials.map((trial) => trial as Map<String, dynamic>).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch trials');
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

  /// Get details of a specific trial
  static Future<Map<String, dynamic>> getTrialDetails(String trialId) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/trials/$trialId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch trial details');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else if (response.statusCode == 404) {
        throw Exception('Trial not found.');
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

  /// Create a new trial
  static Future<Map<String, dynamic>> createTrial({
    required String name,
    required String description,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final requestBody = {
        'name': name,
        'description': description,
        if (additionalData != null) ...additionalData,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/trials'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to create trial');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Insufficient permissions.');
      } else if (response.statusCode == 409) {
        throw Exception('Trial with this name already exists.');
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

  /// Update an existing trial
  static Future<Map<String, dynamic>> updateTrial(
    String trialId, {
    String? name,
    String? description,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final requestBody = {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (additionalData != null) ...additionalData,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/api/trials/$trialId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        } else {
          throw Exception(data['message'] ?? 'Failed to update trial');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Insufficient permissions.');
      } else if (response.statusCode == 404) {
        throw Exception('Trial not found.');
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

  /// Delete a trial
  static Future<bool> deleteTrial(String trialId) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/trials/$trialId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized access. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Insufficient permissions.');
      } else if (response.statusCode == 404) {
        throw Exception('Trial not found.');
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

  /// Get available plots for a specific trial
  static Future<List<Map<String, dynamic>>> getTrialPlots(String trialId) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/fetch-trial'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final trials = data['data'] as List<dynamic>;

          // Find the specific trial
          final trial = trials.firstWhere(
            (t) => t['id'].toString() == trialId,
            orElse: () => null,
          );

          if (trial == null) {
            throw Exception('Trial not found');
          }

          // Extract unique plots from trial_plot_batches
          final plotBatches = trial['trial_plot_batches'] as List<dynamic>? ?? [];
          final plots = <Map<String, dynamic>>[];

          for (var batch in plotBatches) {
            if (batch['plot'] != null) {
              final plot = batch['plot'] as Map<String, dynamic>;
              // Avoid duplicates
              if (!plots.any((p) => p['id'] == plot['id'])) {
                plots.add(plot);
              }
            }
          }

          return plots;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch trial plots');
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

  /// Get available tree numbers for a specific trial and plot
  static Future<List<int>> getTrialPlotTrees(String trialId, String plotId) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/fetch-trial'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final trials = data['data'] as List<dynamic>;

          // Find the specific trial
          final trial = trials.firstWhere(
            (t) => t['id'].toString() == trialId,
            orElse: () => null,
          );

          if (trial == null) {
            throw Exception('Trial not found');
          }

          // Find the plot batch for the specific plot
          final plotBatches = trial['trial_plot_batches'] as List<dynamic>? ?? [];
          final plotBatch = plotBatches.firstWhere(
            (batch) => batch['plot_id'].toString() == plotId,
            orElse: () => null,
          );

          if (plotBatch == null) {
            throw Exception('Plot not found in trial');
          }

          final numberOfTrees = plotBatch['number_of_trees'] as int? ?? 0;

          // Generate tree numbers from 1 to number_of_trees
          return List.generate(numberOfTrees, (index) => index + 1);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch trial plot trees');
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

  /// Submit a trial entry to the API
  static Future<List<Map<String, dynamic>>> submitTrialEntry(Map<String, dynamic> entry) async {
    try {
      final token = await getStorageToken;
      final tokenType = await getTokenType;

      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/trial-trees'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': '$tokenType $token',
        },
        body: json.encode(entry),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final trialTrees = data['trial_trees'] as List<dynamic>;
          return trialTrees.map((t) => t as Map<String, dynamic>).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to submit entry');
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