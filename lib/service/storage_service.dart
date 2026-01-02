import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageHelper {
  static const String entriesKey = 'entries';

  static Future<void> saveEntries(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    
    final serializableEntries = entries.map((entry) {
      final Map<String, dynamic> serialized = {};
      entry.forEach((key, value) {
        if (value is DateTime) {
          serialized[key] = value.toIso8601String();
        } else {
          serialized[key] = value;
        }
      });
      return serialized;
    }).toList();
    
    prefs.setString(entriesKey, jsonEncode(serializableEntries));
  }

  static Future<List<Map<String, dynamic>>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(entriesKey);
    if (jsonString != null) {
      final List decoded = jsonDecode(jsonString);
      return decoded
          .map<Map<String, dynamic>>((e) {
            final map = Map<String, dynamic>.from(e);
            map.forEach((key, value) {
              if (value is String && DateTime.tryParse(value) != null) {
                map[key] = DateTime.parse(value);
              }
            });
            return map;
          })
          .toList();
    }
    return [];
  }
}
