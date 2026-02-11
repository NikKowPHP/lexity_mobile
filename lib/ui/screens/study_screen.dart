import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/srs_item.dart';
import '../../providers/srs_provider.dart';
import '../widgets/liquid_components.dart';
import 'placeholder_screens.dart'; // To use GlassScaffold

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  bool isFlipped = false;

  @override
  void initState() {
    super.initState();
    // Initialize deck for the current language
    Future.microtask(() => ref.read(srsProvider.notifier).loadDeck("Spanish"));
  }

  void _handleReview(int quality) {
    setState(() => isFlipped = false);
    ref.read(srsProvider.notifier).answerCard(quality);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(srsProvider);

    return GlassScaffold(
      title: 'Study',
      subtitle: '${state.deck.length} cards remaining',
      body: SliverFillRemaining(
        hasScrollBody: false,
        child: state.isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : state.currentCard == null 
            ? _buildEmptyState()
            : _buildFlashcard(state.currentCard!),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome, size: 80, color: Colors.white24),
        const SizedBox(height: 16),
        const Text("All caught up!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text("Come back later for more reviews", style: TextStyle(color: Colors.white38)),
        const SizedBox(height: 24),
        LiquidButton(text: "Refresh", onTap: () => ref.read(srsProvider.notifier).loadDeck("Spanish")),
      ],
    );
  }

  Widget _buildFlashcard(SrsItem card) {
    return Column(
      children: [
        const SizedBox(height: 20),
        // 3D Flip Animation
        GestureDetector(
          onTap: () => setState(() => isFlipped = !isFlipped),
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: isFlipped ? 180 : 0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, double val, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateY(val * pi / 180),
                child: val < 90 
                  ? _CardContent(text: card.front, isFront: true)
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _CardContent(text: card.back, isFront: false, contextInfo: card.context),
                    ),
              );
            },
          ),
        ),
        const SizedBox(height: 40),
        
        // Quality Grading Buttons (Only shown when flipped)
        if (isFlipped) 
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _GradeButton(label: "Again", color: Colors.red, val: 0, onTap: _handleReview),
              _GradeButton(label: "Hard", color: Colors.orange, val: 2, onTap: _handleReview),
              _GradeButton(label: "Good", color: Colors.green, val: 3, onTap: _handleReview),
              _GradeButton(label: "Easy", color: Colors.blue, val: 5, onTap: _handleReview),
            ],
          ).animate().fadeIn().slideY(begin: 0.2, end: 0)
        else
          const Text("Tap card to flip", style: TextStyle(color: Colors.white24)),
      ],
    );
  }
}

class _CardContent extends StatelessWidget {
  final String text;
  final bool isFront;
  final String? contextInfo;
  
  const _CardContent({required this.text, required this.isFront, this.contextInfo});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: 0,
      child: Container(
        height: 380,
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isFront ? "QUESTION" : "ANSWER",
              style: TextStyle(color: isFront ? Colors.indigoAccent : Colors.greenAccent, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (!isFront && contextInfo != null) ...[
              const SizedBox(height: 20),
              Text(
                contextInfo!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white38, fontStyle: FontStyle.italic),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  final String label;
  final Color color;
  final int val;
  final Function(int) onTap;

  const _GradeButton({required this.label, required this.color, required this.val, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(val),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.check, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
