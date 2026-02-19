import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';

class StudyMaterialScreen extends StatelessWidget {
  final String title;
  final String content; // Text for Read, VideoID for Listen
  final String mode; // 'reading' or 'listening'
  final String moduleId;

  const StudyMaterialScreen({
    super.key, 
    required this.title, 
    required this.content, 
    required this.mode,
    required this.moduleId,
  });

  @override
  Widget build(BuildContext context) {
    final isReading = mode == 'reading';

    return GlassScaffold(
      title: isReading ? 'Read' : 'Listen',
      subtitle: title,
      body: SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          children: [
            Expanded(
              child: GlassCard(
                child: SingleChildScrollView(
                  child: isReading 
                    ? Text(content, style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.6))
                    : _buildVideoPlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            LiquidButton(
              text: "Write Summary",
              onTap: () => context.push(
                '/journal/new?moduleId=$moduleId&mode=$mode&topic=${Uri.encodeComponent('Summary: $title')}'
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white54),
          ),
        ),
        const SizedBox(height: 16),
        const Text("Video Material Loaded", style: TextStyle(color: Colors.white38)),
      ],
    );
  }
}
