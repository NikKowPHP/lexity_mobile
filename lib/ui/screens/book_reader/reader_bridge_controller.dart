import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../services/logger_service.dart';

/// Callback types for reader events
typedef OnProgressCallback = void Function(String cfi, double pct);
typedef OnTocCallback = void Function(List<dynamic> toc);
typedef OnReadyCallback = void Function();
typedef OnWordTapCallback = void Function(String word, String contextText);
typedef OnTextSelectedCallback =
    void Function(String selectedText, String contextText);
typedef OnParagraphTranslateCallback = void Function(String text);
typedef OnLocationsGeneratedCallback = void Function(String locationsJson);

/// Controller that handles all WebView communication and JavaScript handlers.
/// This bridges the Dart side with the epub.js WebView content.
class ReaderBridgeController {
  final WidgetRef _ref;
  InAppWebViewController? _controller;
  WebMessagePort? _vocabPort;
  Completer<void>? _portReadyCompleter;

  // Callbacks for state updates
  OnProgressCallback? onProgress;
  OnTocCallback? onToc;
  OnReadyCallback? onReady;
  OnWordTapCallback? onWordTap;
  OnTextSelectedCallback? onTextSelected;
  OnParagraphTranslateCallback? onParagraphTranslate;
  OnLocationsGeneratedCallback? onLocationsGenerated;

  ReaderBridgeController(this._ref);

  InAppWebViewController? get controller => _controller;
  WebMessagePort? get vocabPort => _vocabPort;
  bool get isPortReady => _portReadyCompleter?.isCompleted ?? false;

  /// Sets up the controller with JavaScript handlers.
  Future<void> initialize({required InAppWebViewController controller}) async {
    final logger = _ref.read(loggerProvider);
    _controller = controller;
    logger.info('ReaderBridgeController: Initializing');

    _portReadyCompleter = Completer<void>();

    final channel = await controller.createWebMessageChannel();
    _vocabPort = channel!.port1;

    await controller.postWebMessage(
      message: WebMessage(data: 'capture_port', ports: [channel.port2]),
    );

    _setupJavaScriptHandlers();
  }

  void _setupJavaScriptHandlers() {
    if (_controller == null) return;

    _controller!.addJavaScriptHandler(
      handlerName: 'onProgress',
      callback: (args) {
        final cfi = args[0] as String;
        final pct = (args[1] as num).toDouble();
        onProgress?.call(cfi, pct);
      },
    );

    _controller!.addJavaScriptHandler(
      handlerName: 'onToc',
      callback: (args) {
        final tocData = args[0] as List<dynamic>;
        onToc?.call(tocData);
      },
    );

    _controller!.addJavaScriptHandler(
      handlerName: 'onParagraphTranslate',
      callback: (args) {
        final text = args[0].toString();
        onParagraphTranslate?.call(text);
      },
    );

    _controller!.addJavaScriptHandler(
      handlerName: 'onReady',
      callback: (_) async {
        final logger = _ref.read(loggerProvider);
        logger.info('ReaderBridgeController: onReady fired');
        _portReadyCompleter?.complete();
        onReady?.call();
      },
    );

    _controller!.addJavaScriptHandler(
      handlerName: 'onWordTap',
      callback: (args) {
        final word = args[0] as String;
        final contextText = args[3] as String;
        onWordTap?.call(word, contextText);
      },
    );

    _controller!.addJavaScriptHandler(
      handlerName: 'onBackgroundTap',
      callback: (_) {
        // No action needed for background tap
      },
    );

    _controller!.addJavaScriptHandler(
      handlerName: 'onTextSelected',
      callback: (args) {
        onTextSelected?.call(args[0].toString(), args[1].toString());
      },
    );

    _controller!.addJavaScriptHandler(
      handlerName: 'onLocationsGenerated',
      callback: (args) {
        final String locationsJson = args[0] as String;
        final logger = _ref.read(loggerProvider);
        if (locationsJson == "[]" || locationsJson.isEmpty) {
          logger.warning(
            'ReaderBridgeController: Received empty locations from JS, skipping sync.',
          );
          return;
        }
        onLocationsGenerated?.call(locationsJson);
      },
    );
  }

  /// Posts a message to the WebView via WebMessagePort.
  void postToWeb(String type, dynamic payload) {
    if (_vocabPort != null) {
      try {
        _vocabPort!.postMessage(
          WebMessage(data: {'type': type, 'payload': payload}),
        );
      } catch (e) {
        final logger = _ref.read(loggerProvider);
        logger.warning(
          'ReaderBridgeController: Failed to post message to web: $e',
        );
      }
    }
  }

  /// Updates the reader theme and font size in the WebView.
  void updateTheme(
    Map<String, String> colors,
    double fontSize,
    String themeName,
  ) {
    postToWeb('UPDATE_THEME', {
      'colors': colors,
      'fontSize': fontSize,
      'themeName': themeName,
    });
  }

  /// Sends locations to the WebView.
  void sendLocations(dynamic locations) {
    postToWeb('SET_LOCATIONS', locations);
  }

  /// Sends vocabulary delta to the WebView.
  void sendVocabDelta(Map<String, String> delta) {
    if (_vocabPort != null) {
      _vocabPort!.postMessage(
        WebMessage(data: {'type': 'vocab_delta', 'delta': delta}),
      );
    }
  }

  /// Signals that the port is ready.
  void signalPortReady() {
    postToWeb('PORT_READY', null);
  }

  /// Sends shutdown signal to the WebView.
  void shutdown() {
    postToWeb('SHUTDOWN', null);
  }

  /// Closes the WebMessagePort.
  Future<void> closePort() async {
    await _vocabPort?.close().catchError((_) {});
    _vocabPort = null;
  }

  /// Sends a command to the WebView via postMessage.
  void sendCommand(String command, dynamic payload) {
    postToWeb('command', {'cmd': command, 'data': payload});
  }

  /// Clears the selection in the WebView.
  void clearSelection() {
    sendCommand('clearSelection', null);
  }

  /// Gets visible unknown words from the WebView.
  Future<List<String>> getVisibleUnknownWords() async {
    if (_controller == null) return [];
    final result = await _controller!.evaluateJavascript(
      source: "window.getVisibleUnknownWords();",
    );
    if (result != null && result is List) {
      return result.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// Navigates to a specific href in the reader.
  void displayHref(String href) {
    sendCommand('displayHref', {'href': href});
  }

  /// Loads a book in the WebView.
  void loadBook({
    required String bookUrl,
    required String initialCfi,
    required Map<String, String> colors,
    required String themeName,
    required double fontSize,
  }) {
    if (_controller == null) return;

    sendCommand('loadBook', {
      'url': bookUrl,
      'initialCfi': initialCfi,
      'theme': colors,
      'themeName': themeName,
      'fontSize': fontSize,
      'vocabMap': null,
    });
  }

  void dispose() {
    _portReadyCompleter = null;
  }
}
