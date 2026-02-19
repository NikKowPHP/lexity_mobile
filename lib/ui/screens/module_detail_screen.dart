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

        // Activity Statuses
        final isWritingDone = activities['writing']?['completed'] == true;
        final isSrsDone = activities['srs']?['completed'] == true;
        final isDrillDone = activities['drill']?['completed'] == true;
        
        final hasSrs = activities.containsKey('srs');
        final hasDrill = activities.containsKey('drill');

        // Check if user can complete the module (all activities done)
        final canComplete = isWritingDone && 
                            (!hasSrs || isSrsDone) && 
                            (!hasDrill || isDrillDone);
        
        final isModuleCompleted = module.status == 'COMPLETED';

        return GlassScaffold(
          title: module.title,
          subtitle: "Focus: ${module.targetConceptTag.replaceAll('_', ' ')}",
          body: SliverList(
            delegate: SliverChildListDelegate([
              // Micro Lesson Section
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
                      height: 1.5,
                    ),
                    h2: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      height: 1.5,
                    ),
                    h3: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      height: 1.5,
                    ),
                    listBullet: TextStyle(
                      color: LiquidTheme.primaryAccent,
                      fontSize: 16,
                    ),
                    em: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.white70,
                    ),
                    strong: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    blockquote: const TextStyle(
                      color: Colors.white60,
                      fontStyle: FontStyle.italic,
                    ),
                    code: TextStyle(
                      color: LiquidTheme.secondaryAccent,
                      backgroundColor: Colors.transparent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Activities Section
              const Text("ACTIVITIES", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              
              _ActivityTile(
                title: "Write a journal entry",
                subtitle: activities['writing']?['title'] ?? "Practice this concept",
                isCompleted: isWritingDone,
                icon: Icons.edit,
                onTap: () {
                   if (!isWritingDone) {
                     context.push('/journal/new?moduleId=$moduleId'); 
                   }
                },
              ),

              if (hasSrs)
                _ActivityTile(
                  title: "Study Session",
                  subtitle: "Reinforce with SRS",
                  isCompleted: isSrsDone,
                  icon: Icons.style,
                  onTap: () {
                    if (!isSrsDone) {
                      context.go('/study'); 
                    }
                  },
                ),

              if (hasDrill)
                _ActivityTile(
                  title: "Practice Drill",
                  subtitle: "Targeted exercise",
                  isCompleted: isDrillDone,
                  icon: Icons.psychology,
                  onTap: () {
                    if (!isDrillDone) {
                      context.push('/path/drill/$moduleId');
                    }
                  },
                ),

              const SizedBox(height: 32),

              if (!isModuleCompleted)
                LiquidButton(
                  text: canComplete ? "Complete Module" : "Finish Activities to Complete",
                  isLoading: false,
                  onTap: canComplete ? () async {
                    await ref.read(pathNotifierProvider.notifier).completeModule(module.id);
                    if (context.mounted) context.pop();
                  } : () {},
                ),
                
               if (isModuleCompleted)
                 const Center(
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.check_circle, color: Colors.greenAccent),
                       SizedBox(width: 8),
                       Text("Module Completed", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                     ],
                   ),
                 )
            ]),
          ),
        );
      },
    );
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
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isCompleted ? Colors.green.withValues(alpha: 0.3) : Colors.white10),
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (!isCompleted)
              const Icon(Icons.arrow_forward, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
