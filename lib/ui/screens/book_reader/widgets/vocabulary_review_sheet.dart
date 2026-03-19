import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lexity_mobile/providers/vocabulary_provider.dart';
import 'package:lexity_mobile/services/translation_service.dart';
import 'package:lexity_mobile/providers/user_provider.dart';
import 'package:lexity_mobile/providers/srs_provider.dart';
import 'package:lexity_mobile/theme/liquid_theme.dart';
import '../../../widgets/liquid_components.dart';

/// A bottom sheet that presents newly encountered vocabulary words
/// for batch review — allowing the user to mark words as known
/// or add them to their study deck.
class VocabularyReviewSheet extends ConsumerStatefulWidget {
  final List<String> words;
  final String targetLanguage;
  final InAppWebViewController? webViewController;

  const VocabularyReviewSheet({
    super.key,
    required this.words,
    required this.targetLanguage,
    this.webViewController,
  });

  /// Shows the vocabulary review bottom sheet as a modal.
  static Future<void> show({
    required BuildContext context,
    required List<String> words,
    required String targetLanguage,
    InAppWebViewController? webViewController,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => VocabularyReviewSheet(
        words: words,
        targetLanguage: targetLanguage,
        webViewController: webViewController,
      ),
    );
  }

  @override
  ConsumerState<VocabularyReviewSheet> createState() =>
      _VocabularyReviewSheetState();
}

class _VocabularyReviewSheetState extends ConsumerState<VocabularyReviewSheet> {
  late List<String> _pendingWords;

  @override
  void initState() {
    super.initState();
    _pendingWords = List.from(widget.words);
  }

  void _removeWord(String word) {
    setState(() {
      _pendingWords.remove(word);
    });
    if (_pendingWords.isEmpty) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${_pendingWords.length} New Words",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "How do you want to handle these words?",
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: ListView.builder(
              itemCount: _pendingWords.length,
              itemBuilder: (context, i) => VocabListItem(
                word: _pendingWords[i],
                targetLanguage: widget.targetLanguage,
                webViewController: widget.webViewController,
                onMarkKnown: () {
                  ref
                      .read(vocabularyProvider.notifier)
                      .updateWordStatus(
                        _pendingWords[i],
                        'known',
                        widget.targetLanguage,
                      );
                  _removeWord(_pendingWords[i]);
                },
                onAddedToDeck: () {
                  ref
                      .read(vocabularyProvider.notifier)
                      .updateWordStatus(
                        _pendingWords[i],
                        'learning',
                        widget.targetLanguage,
                      );
                  _removeWord(_pendingWords[i]);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: LiquidButton(
                  text: "Mark All Known",
                  onTap: () {
                    ref
                        .read(vocabularyProvider.notifier)
                        .markBatchKnown(_pendingWords, widget.targetLanguage);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "I'll handle them manually",
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single vocabulary word item within [VocabularyReviewSheet].
/// Expands on tap to show translation and action buttons.
class VocabListItem extends ConsumerStatefulWidget {
  final String word;
  final String targetLanguage;
  final InAppWebViewController? webViewController;
  final VoidCallback onMarkKnown;
  final VoidCallback onAddedToDeck;

  const VocabListItem({
    super.key,
    required this.word,
    required this.targetLanguage,
    this.webViewController,
    required this.onMarkKnown,
    required this.onAddedToDeck,
  });

  @override
  ConsumerState<VocabListItem> createState() => _VocabListItemState();
}

class _VocabListItemState extends ConsumerState<VocabListItem> {
  bool _expanded = false;
  bool _loading = false;
  String? _translation;

  void _toggle() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && _translation == null) {
      setState(() => _loading = true);
      try {
        final nativeLang =
            ref.read(userProfileProvider).value?.nativeLanguage ?? 'english';
        final res = await ref
            .read(translationServiceProvider)
            .translate(widget.word, widget.targetLanguage, nativeLang);
        if (mounted) {
          setState(() {
            _translation = res;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _translation = "Error translating";
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              widget.word,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onTap: _toggle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.greenAccent),
                  onPressed: widget.onMarkKnown,
                  tooltip: "Mark Known",
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: LiquidTheme.primaryAccent),
                  onPressed: () async {
                    if (_translation == null) {
                      setState(() => _loading = true);
                      try {
                        final nativeLang =
                            ref
                                .read(userProfileProvider)
                                .value
                                ?.nativeLanguage ??
                            'english';
                        final res = await ref
                            .read(translationServiceProvider)
                            .translate(
                              widget.word,
                              widget.targetLanguage,
                              nativeLang,
                            );
                        _translation = res;
                      } catch (e) {
                        _translation = "Unknown";
                      }
                    }
                    if (mounted) {
                      ref
                          .read(srsProvider.notifier)
                          .addToDeckFromTranslation(
                            front: widget.word,
                            back: _translation!,
                            language: widget.targetLanguage,
                          );
                      widget.onAddedToDeck();
                    }
                  },
                  tooltip: "Add to Deck",
                ),
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.subdirectory_arrow_right,
                          size: 16,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _translation ?? "Error",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
