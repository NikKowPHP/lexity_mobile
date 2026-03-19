import 'dart:convert';
import 'dart:isolate';

/// Utility class for parsing large JSON data in a background isolate.
/// This prevents the main thread from freezing during heavy JSON operations.
///
/// Usage:
/// ```dart
/// // Parse a JSON string to Map
/// final map = await IsolateJsonParser.parseJson(jsonString);
///
/// // Parse a JSON string to List
/// final list = await IsolateJsonParser.parseJsonList(jsonString);
///
/// // Parse a list of model objects
/// final items = await IsolateJsonParser.parseModels<T>(
///   jsonString,
///   (json) => MyModel.fromJson(json),
/// );
/// ```
class IsolateJsonParser {
  /// Parses a JSON string into a Map using a background isolate.
  ///
  /// Use this for large JSON objects (100+ keys) to prevent main thread freezes.
  static Future<Map<String, dynamic>> parseJson(String json) async {
    return await Isolate.run(() => jsonDecode(json) as Map<String, dynamic>);
  }

  /// Parses a JSON string into a List using a background isolate.
  ///
  /// Use this for large JSON arrays (100+ items) to prevent main thread freezes.
  static Future<List<dynamic>> parseJsonList(String json) async {
    return await Isolate.run(() => jsonDecode(json) as List<dynamic>);
  }

  /// Parses a JSON string into a List of [T] using a background isolate.
  ///
  /// The [fromJson] function is used to convert each JSON object to model [T].
  ///
  /// Use this for large lists of model objects to prevent main thread freezes.
  static Future<List<T>> parseModels<T>(
    String json,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    return await Isolate.run(() {
      final List<dynamic> decoded = jsonDecode(json) as List<dynamic>;
      return decoded
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  /// Parses a list of JSON strings into a list of Maps using a background isolate.
  ///
  /// Useful when you have multiple JSON strings that need to be parsed together.
  static Future<List<Map<String, dynamic>>> parseJsonListFromStrings(
    List<String> jsonStrings,
  ) async {
    return await Isolate.run(() {
      return jsonStrings
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
    });
  }

  /// Parses a list of model objects from a JSON string using a background isolate.
  ///
  /// The [fromJson] function is used to convert each JSON object to model [T].
  ///
  /// This is more efficient than parsing individual strings when dealing with
  /// large datasets.
  static Future<List<T>> parseModelsFromList<T>(
    List<dynamic> jsonList,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    return await Isolate.run(() {
      return jsonList
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }
}
