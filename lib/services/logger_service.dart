import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LoggerService {
  late Logger _logger;
  File? _logFile;

  LoggerService() {
    _initLogger();
  }

  Future<void> _initLogger() async {
    // Console logger with pretty printer
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );

    // Initialize file logging
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/app_logs.txt';
      _logFile = File(filePath);
      
      // Rotate log file if too large > 5MB
      if (await _logFile!.exists()) {
        final stat = await _logFile!.stat();
        if (stat.size > 5 * 1024 * 1024) {
          final backupPath = '${directory.path}/app_logs_${DateTime.now().millisecondsSinceEpoch}.txt';
          await _logFile!.rename(backupPath);
          _logFile = File(filePath);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to initialize file logger: $e");
      }
    }
  }

  void _logToFile(Level level, String message, [dynamic error, StackTrace? stackTrace]) {
    if (_logFile == null) return;
    
    final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logEntry = '[$time] [${level.name}] $message\n${error != null ? 'Error: $error\n' : ''}${stackTrace != null ? 'StackTrace: $stackTrace\n' : ''}';
    
    _logFile!.writeAsString(logEntry, mode: FileMode.append).catchError((e) {
      if (kDebugMode) {
        print("Failed to write to log file: $e");
      }
      return _logFile!;
    });
  }

  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
    _logToFile(Level.debug, message, error, stackTrace);
  }

  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
    _logToFile(Level.info, message, error, stackTrace);
  }

  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
    _logToFile(Level.warning, message, error, stackTrace);
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
    _logToFile(Level.error, message, error, stackTrace);
  }
}

final loggerProvider = Provider<LoggerService>((ref) {
  return LoggerService();
});
