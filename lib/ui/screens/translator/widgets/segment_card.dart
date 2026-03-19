import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/translation_result.dart';
import '../../../../providers/srs_provider.dart';
import '../../../../theme/liquid_theme.dart';
import '../../../widgets/liquid_components.dart';

/// Card widget displaying a single translation segment with add-to-deck action.
class SegmentCard extends ConsumerStatefulWidget {
  final TranslationSegment segment;
  final String targetLanguage;

  const SegmentCard({
    super.key,
    required this.segment,
    required this.targetLanguage,
  });

  @override
  ConsumerState<SegmentCard> createState() => SegmentCardState();
}

class SegmentCardState extends ConsumerState<SegmentCard> {
  bool _isAdding = false;
  bool _isAdded = false;

  Future<void> _handleAddToDeck() async {
    setState(() => _isAdding = true);
    final success = await ref
        .read(srsProvider.notifier)
        .addToDeckFromTranslation(
          front: widget.segment.source,
          back: widget.segment.translation,
          language: widget.targetLanguage.toLowerCase(),
          explanation: widget.segment.explanation,
        );

    if (mounted) {
      setState(() {
        _isAdding = false;
        if (success) _isAdded = true;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Added to Study Deck",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: LiquidTheme.primaryAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.segment.source,
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
                IconButton(
                  onPressed: (_isAdded || _isAdding) ? null : _handleAddToDeck,
                  icon: _isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white24,
                          ),
                        )
                      : Icon(
                          _isAdded ? Icons.check_circle : Icons.add_circle,
                          color: _isAdded
                              ? Colors.greenAccent
                              : LiquidTheme.primaryAccent,
                          size: 24,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.segment.translation,
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 14,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.segment.explanation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
