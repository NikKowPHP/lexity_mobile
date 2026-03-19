import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexity_mobile/providers/srs_provider.dart';
import 'package:lexity_mobile/providers/vocabulary_provider.dart';
import 'package:lexity_mobile/services/translation_service.dart';
import 'package:lexity_mobile/theme/liquid_theme.dart';

/// Callback when a word is added to the study deck.
typedef OnWordAddedToDeck = void Function();

/// A bottom sheet that displays AI-powered contextual translation
/// with the option to add the word to a study deck.
class TranslationBottomSheet extends ConsumerStatefulWidget {
  final String selectedText;
  final String contextText;
  final String sourceLang;
  final String targetLang;
  final VoidCallback? onDismissed;

  const TranslationBottomSheet({
    super.key,
    required this.selectedText,
    required this.contextText,
    required this.sourceLang,
    required this.targetLang,
    this.onDismissed,
  });

  /// Shows the translation bottom sheet as a modal.
  static Future<void> show({
    required BuildContext context,
    required String selectedText,
    required String contextText,
    required String sourceLang,
    required String targetLang,
    VoidCallback? onDismissed,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => TranslationBottomSheet(
        selectedText: selectedText,
        contextText: contextText,
        sourceLang: sourceLang,
        targetLang: targetLang,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  ConsumerState<TranslationBottomSheet> createState() =>
      _TranslationBottomSheetState();
}

class _TranslationBottomSheetState
    extends ConsumerState<TranslationBottomSheet> {
  StreamSubscription? _translationSub;
  bool _isFinal = false;
  String? _contextualTranslation;
  String? _explanation;
  bool _isAdding = false;
  bool _isAdded = false;

  @override
  void initState() {
    super.initState();
    _startHybridTranslation();
  }

  void _startHybridTranslation() {
    _translationSub = ref
        .read(translationServiceProvider)
        .streamContextualTranslation(
          selectedText: widget.selectedText,
          context: widget.contextText,
          sourceLanguage: widget.sourceLang,
          targetLanguage: widget.targetLang,
        )
        .listen((data) {
          if (mounted) {
            setState(() {
              _contextualTranslation = data['translation'];
              _explanation = data['explanation'];
              _isFinal = data['isFinal'] ?? false;
            });
          }
        });
  }

  @override
  void dispose() {
    _translationSub?.cancel();
    super.dispose();
  }

  Future<void> _handleAddToDeck() async {
    setState(() => _isAdding = true);
    final success = await ref
        .read(srsProvider.notifier)
        .addToDeckFromTranslation(
          front: widget.selectedText,
          back: _contextualTranslation!,
          language: widget.sourceLang,
          explanation: _explanation,
        );

    if (mounted) {
      setState(() {
        _isAdding = false;
        if (success) {
          _isAdded = true;
          ref
              .read(vocabularyProvider.notifier)
              .updateWordStatus(
                widget.selectedText,
                'learning',
                widget.sourceLang,
              );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.selectedText,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          if (!_isFinal)
            const LinearProgressIndicator(
              minHeight: 2,
              color: LiquidTheme.primaryAccent,
            )
          else
            const SizedBox(height: 2),

          const SizedBox(height: 8),

          if (_contextualTranslation != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _contextualTranslation!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _explanation ?? "",
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(
                  color: LiquidTheme.secondaryAccent,
                ),
              ),
            ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdded
                    ? Colors.green.withValues(alpha: 0.2)
                    : LiquidTheme.primaryAccent,
                foregroundColor: _isAdded ? Colors.greenAccent : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: (!_isFinal || _isAdded || _isAdding)
                  ? null
                  : _handleAddToDeck,
              icon: _isAdding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isAdded ? Icons.check : Icons.add),
              label: Text(
                _isAdded ? "Added to Deck" : "Add to Study Deck",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
