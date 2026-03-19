import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../providers/vocabulary_provider.dart';
import '../../../services/logger_service.dart';
import '../book_reader_html.dart';

/// Service that manages the local HTTP server for serving EPUB files
/// and handles book downloading when not already available locally.
class ReaderFileService {
  final WidgetRef _ref;
  HttpServer? _server;
  int? _port;
  bool _isStarting = false;

  ReaderFileService(this._ref);

  bool get isRunning => _server != null;
  int? get port => _port;

  /// Starts the local HTTP server on a random available port.
  /// Returns the port number the server is bound to.
  Future<int> start() async {
    final logger = _ref.read(loggerProvider);

    if (kIsWeb) {
      logger.info('ReaderFileService: Web detected, skipping local server.');
      _port = 0;
      return 0;
    }

    // Prevent double-start if already running
    if (_server != null) {
      return _port!;
    }

    // Wait for any concurrent start attempt
    if (_isStarting) {
      logger.info('ReaderFileService: Start already in progress, waiting...');
      while (_isStarting) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return _port ?? 0;
    }

    _isStarting = true;
    logger.info('ReaderFileService: Initializing local file server');

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      logger.info('ReaderFileService: Local server bound to port $_port');
    } on SocketException catch (e) {
      logger.error('ReaderFileService: Failed to bind to port: $e');
      _server = null;
      _port = null;
      _isStarting = false;
      rethrow;
    } finally {
      _isStarting = false;
    }

    _server!.listen((HttpRequest request) async {
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add(
        'Access-Control-Allow-Methods',
        'GET, OPTIONS',
      );
      request.response.headers.add('Access-Control-Allow-Headers', '*');

      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
        await request.response.close();
        return;
      }

      // Serve the reader HTML at the root
      if (request.uri.path == '/') {
        request.response.headers.contentType = ContentType.html;

        // Inject current vocab into the server response
        final currentVocab = _ref.read(vocabularyProvider).value ?? {};
        final String injectedHtml = bookReaderHtmlTemplate.replaceFirst(
          'window.vocabMap = {};',
          'window.vocabMap = ${jsonEncode(currentVocab)};',
        );

        request.response.write(injectedHtml);
        await request.response.close();
        return;
      }

      // Serve EPUB files
      if (request.uri.path.startsWith('/books/')) {
        final bookId = request.uri.pathSegments.last.replaceAll('.epub', '');
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/books/$bookId.epub');

        if (await file.exists()) {
          logger.debug(
            'ReaderFileService: Serving local EPUB file for $bookId',
          );
          final length = await file.length();
          request.response.contentLength = length;
          request.response.headers.contentType = ContentType(
            'application',
            'epub+zip',
            charset: 'utf-8',
          );
          await request.response.addStream(file.openRead());
          await request.response.close();
          return;
        }
      }

      request.response.statusCode = 404;
      await request.response.close();
    });

    return _port!;
  }

  /// Stops the local HTTP server.
  void stop() {
    _server?.close(force: true);
    _server = null;
    _port = null;
    _isStarting = false;
  }

  /// Ensures the book is downloaded locally.
  /// Returns true if the book is ready (already downloaded or successfully downloaded).
  /// Sets [isDownloading] and [downloadProgress] via callbacks during download.
  Future<bool> ensureBookDownloaded({
    required String bookId,
    required String? signedUrl,
    required String bookTitle,
    required void Function(bool) setIsDownloading,
    required void Function(double) setDownloadProgress,
    required void Function(bool) setLocalFileReady,
    required bool isDownloading,
    required bool localFileReady,
  }) async {
    final logger = _ref.read(loggerProvider);

    if (isDownloading || localFileReady) {
      return localFileReady;
    }

    if (kIsWeb) {
      setLocalFileReady(true);
      return true;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${dir.path}/books');
      if (!await booksDir.exists()) await booksDir.create(recursive: true);

      final file = File('${booksDir.path}/$bookId.epub');
      if (await file.exists()) {
        logger.info('ReaderFileService: Book "$bookTitle" found locally');
        setLocalFileReady(true);
        return true;
      }

      logger.info(
        'ReaderFileService: Book not found locally, starting download for "$bookTitle"',
      );

      if (signedUrl == null) {
        logger.error('ReaderFileService: Missing signedUrl for book $bookId');
        throw Exception("No download URL provided");
      }

      setIsDownloading(true);
      setDownloadProgress(0.0);

      final request = http.Request('GET', Uri.parse(signedUrl));
      final response = await request.send();
      final total = response.contentLength ?? 0;
      int received = 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0) {
          setDownloadProgress(received / total);
        }
      }

      await file.writeAsBytes(bytes);
      logger.info('ReaderFileService: Download complete for "$bookTitle"');
      setIsDownloading(false);
      setLocalFileReady(true);
      return true;
    } catch (e, st) {
      logger.error('ReaderFileService: Download failed', e, st);
      setIsDownloading(false);
      return false;
    }
  }
}
