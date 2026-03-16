import 'package:flutter/material.dart';
import '../../models/journal_entry.dart';
import 'liquid_components.dart';
import '../../theme/liquid_theme.dart';

class AnalysisScoreCard extends StatelessWidget {
  final Analysis analysis;

  const AnalysisScoreCard({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ScoreBox(label: "Grammar", score: analysis.grammarScore)),
        const SizedBox(width: 12),
        Expanded(child: _ScoreBox(label: "Phrasing", score: analysis.phrasingScore)),
        const SizedBox(width: 12),
        Expanded(child: _ScoreBox(label: "Vocabulary", score: analysis.vocabScore)),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final int score;

  const _ScoreBox({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: 12,
      child: Column(
        children: [
          Text(
            "$score%",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: LiquidTheme.primaryAccent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class MistakesList extends StatelessWidget {
  final List<Mistake> mistakes;

  const MistakesList({super.key, required this.mistakes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: mistakes.map((m) => _MistakeCard(mistake: m)).toList(),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  final Mistake mistake;

  const _MistakeCard({required this.mistake});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                   child: Text(mistake.type.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                 ),
              ],
            ),
            const SizedBox(height: 8),
            Text(mistake.original, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.white54)),
            Text(mistake.corrected, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(mistake.explanation, style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
