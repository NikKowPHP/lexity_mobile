import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/path_provider.dart';
import '../../theme/liquid_theme.dart';

class ModuleDetailScreen extends ConsumerWidget {
  final String moduleId;
  const ModuleDetailScreen({super.key, required this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(learningPathProvider);

    return pathAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text("Error: $e"))),
      data: (modules) {
        final module = modules.firstWhere((m) => m.id == moduleId, orElse: () => modules.first);
        final activities = module.activities;

        return GlassScaffold(
          title: module.title,
          subtitle: "Focus: ${module.targetConceptTag.replaceAll('_', ' ')}",
          body: SliverList(
            delegate: SliverChildListDelegate([
              // 1. Micro Lesson
              const Text("MICRO-LESSON", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              GlassCard(
                child: MarkdownBody(
                  data: module.microLesson,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      color: Colors.white,
                      height: 1.6,
                      fontSize: 15,
                    ),
                    h1: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                    strong: const TextStyle(
                      color: LiquidTheme.primaryAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 2. Dynamic Activities List
              const Text(
                "ACTIVITIES",
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),

              ..._buildActivityTiles(context, activities, moduleId),

              const SizedBox(height: 32),

              // 3. Completion Logic
              if (module.status != 'COMPLETED')
                LiquidButton(
                  text: _isAllDone(activities)
                      ? "Check My Understanding"
                      : "Complete Activities to Finish",
                  onTap: _isAllDone(activities)
                      ? () => ref
                            .read(pathNotifierProvider.notifier)
                            .completeModule(module.id)
                      : () {},
                )
              else
                const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text(
                        "Module Mastered",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }

  bool _isAllDone(Map<String, dynamic> activities) {
    return activities.values.every((a) => a['completed'] == true);
  }

  List<Widget> _buildActivityTiles(
    BuildContext context,
    Map<String, dynamic> activities,
    String moduleId,
  ) {
    List<Widget> tiles = [];

    // Writing
    if (activities.containsKey('writing')) {
      final act = activities['writing'];
      tiles.add(
        _ActivityTile(
          title: "Write a journal entry",
          subtitle: act['title'] ?? "Apply what you've learned",
          isCompleted: act['completed'] == true,
          icon: Icons.edit_note,
          onTap: () => context.push(
            '/journal/new?moduleId=$moduleId&topic=${Uri.encodeComponent(act['title'])}',
          ),
        ),
      );
    }

    // SRS
    if (activities.containsKey('srs')) {
      final act = activities['srs'];
      tiles.add(
        _ActivityTile(
          title: "Study Session",
          subtitle: "Reinforce with Spaced Repetition",
          isCompleted: act['completed'] == true,
          icon: Icons.psychology,
          onTap: () => context.go('/study'),
        ),
      );
    }

    // Drill
    if (activities.containsKey('drill')) {
      final act = activities['drill'];
      tiles.add(
        _ActivityTile(
          title: "Practice Drill",
          subtitle: act['explanation'] ?? "Targeted exercise",
          isCompleted: act['completed'] == true,
          icon: Icons.ads_click,
          onTap: () => context.push('/path/drill/$moduleId'),
        ),
      );
    }

    // Reading
    if (activities.containsKey('reading')) {
      final act = activities['reading'];
      tiles.add(
        _ActivityTile(
          title: "Read & Write",
          subtitle: "Comprehension challenge",
          isCompleted: act['completed'] == true,
          icon: Icons.menu_book,
          onTap: () => context.push('/path/read?moduleId=$moduleId'),
        ),
      );
    }

    // Listening
    if (activities.containsKey('listening')) {
      final act = activities['listening'];
      tiles.add(
        _ActivityTile(
          title: "Listen & Write",
          subtitle: "Video comprehension",
          isCompleted: act['completed'] == true,
          icon: Icons.headset,
          onTap: () => context.push(
            '/path/material?moduleId=$moduleId&mode=listening&title=${Uri.encodeComponent('Video')}&content=${Uri.encodeComponent(act['videoId'] ?? '')}',
          ),
        ),
      );
    }

    // Audio Journal
    if (activities.containsKey('audio_journal')) {
      tiles.add(
        _ActivityTile(
          title: "Speak a Journal Entry",
          subtitle: "Verbal fluency practice",
          isCompleted: activities['audio_journal']['completed'] == true,
          icon: Icons.mic,
          onTap: () => context.push(
            '/journal/new?moduleId=$moduleId&mode=audio_journal&topic=${Uri.encodeComponent('Spoken Entry')}',
          ),
        ),
      );
    }

    // Describe Image
    if (activities.containsKey('describe_image')) {
      final act = activities['describe_image'];
      tiles.add(
        _ActivityTile(
          title: "Describe an Image",
          subtitle: "Visual vocabulary practice",
          isCompleted: act['completed'] == true,
          icon: Icons.image,
          onTap: () => context.push(
            '/journal/new?moduleId=$moduleId&mode=describe_image&imageUrl=${Uri.encodeComponent(act['imageUrl'])}&topic=${Uri.encodeComponent(act['title'] ?? 'Image Description')}',
          ),
        ),
      );
    }

    return tiles;
  }
}

class _ActivityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final IconData icon;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCompleted ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted
              ? Colors.greenAccent.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? Colors.greenAccent.withValues(alpha: 0.3)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : icon,
              color: isCompleted ? Colors.greenAccent : Colors.white70,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.white60 : Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!isCompleted)
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.white24,
              ),
          ],
        ),
      ),
    );
  }
}
