import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/srs_provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../../services/translation_service.dart';
import '../../theme/liquid_theme.dart';

class TranslationTooltip extends ConsumerStatefulWidget {
  final String selectedText;
  final String contextText;
  final String sourceLang;
  final String targetLang;
  final double x;
  final double y;
  final VoidCallback onClose;

  const TranslationTooltip({
    super.key,
    required this.selectedText,
    required this.contextText,
    required this.sourceLang,
    required this.targetLang,
    required this.x,
    required this.y,
    required this.onClose,
  });

  @override
  ConsumerState<TranslationTooltip> createState() => _TranslationTooltipState();
}

class _TranslationTooltipState extends ConsumerState<TranslationTooltip> {
  bool _isLoading = true;
  String? _translation;
  String? _explanation;
  bool _isAdding = false;
  bool _isAdded = false;

  @override
  void initState() {
    super.initState();
    _fetchTranslation();
  }

  Future<void> _fetchTranslation() async {
    try {
      final translationService = ref.read(translationServiceProvider);
      final result = await translationService.contextualTranslate(
        selectedText: widget.selectedText,
        context: widget.contextText,
        sourceLanguage: widget.sourceLang,
        targetLanguage: widget.targetLang,
        nativeLanguage: widget.targetLang,
      );
      if (mounted) {
        setState(() {
          _translation = result['translation'];
          _explanation = result['explanation'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _translation = "Failed to translate";
        });
      }
    }
  }

  Future<void> _handleAddToDeck() async {
    setState(() => _isAdding = true);
    final success = await ref
        .read(srsProvider.notifier)
        .addToDeckFromTranslation(
          front: widget.selectedText,
          back: _translation!,
          language: widget.sourceLang,
          explanation: _explanation,
        );

    if (mounted) {
      setState(() {
        _isAdding = false;
        if (success) {
          _isAdded = true;
          // Instantly update vocabulary state locally and remotely
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
    final screenWidth = MediaQuery.of(context).size.width;
    final tooltipWidth = 280.0;

    double left = widget.x - (tooltipWidth / 2);
    if (left < 16) left = 16;
    if (left + tooltipWidth > screenWidth - 16)
      left = screenWidth - tooltipWidth - 16;

    double top = widget.y + 10;
    if (top > MediaQuery.of(context).size.height - 200) {
      top = widget.y - 180;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: tooltipWidth,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.selectedText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Text(
                  _translation ?? "",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (_explanation != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _explanation!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAdded
                          ? Colors.green.withValues(alpha: 0.2)
                          : LiquidTheme.primaryAccent.withValues(alpha: 0.2),
                      foregroundColor: _isAdded
                          ? Colors.greenAccent
                          : LiquidTheme.primaryAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: (_isAdded || _isAdding)
                        ? null
                        : _handleAddToDeck,
                    icon: _isAdding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isAdded ? Icons.check : Icons.add, size: 16),
                    label: Text(_isAdded ? "Added" : "Add to Deck"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
