import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/path_provider.dart';
import '../../models/learning_module.dart';

class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(learningPathProvider);

    return GlassScaffold(
      title: 'Your Path',
      subtitle: 'Personalized Curriculum',
      showBackButton: false,
      body: pathAsync.when(
        loading: () => const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (e, _) => SliverFillRemaining(
          child: Center(
            child: Text(
              "Error loading path: $e",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        data: (modules) {
          // Router now handles redirect to /onboarding if not completed
          // so we can assume here that onboarding is done
          
          if (modules.isEmpty) {
            return SliverFillRemaining(
              child: Center(
                child: LiquidButton(
                  text: "Generate First Module",
                  onTap: () => ref
                      .read(pathNotifierProvider.notifier)
                      .generateNextModule(),
                ),
              ),
            );
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final module = modules[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () {
                      if (module.status != 'PENDING') {
                        context.push('/path/module/${module.id}');
                      }
                    },
                    child: _TimelineModuleItem(module: module, index: index),
                  ),
                );
              },
              childCount: modules.length,
            ),
          );
        },
      ),
    );
  }
}

class _TimelineModuleItem extends StatelessWidget {
  final LearningModule module;
  final int index;

  const _TimelineModuleItem({required this.module, required this.index});

  @override
  Widget build(BuildContext context) {
    final isCompleted = module.status == 'COMPLETED';
    final isPending = module.status == 'PENDING';
    final isInProgress = module.status == 'IN_PROGRESS';

    return GlassCard(
      padding: 16,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isPending
                  ? Colors.white10
                  : (isCompleted
                        ? Colors.green.withValues(alpha: 0.2)
                        : LiquidTheme.primaryAccent.withValues(alpha: 0.2)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPending
                  ? Icons.lock
                  : (isCompleted ? Icons.check : Icons.play_arrow),
              color: isPending
                  ? Colors.white38
                  : (isCompleted
                        ? Colors.greenAccent
                        : LiquidTheme.primaryAccent),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isPending ? Colors.white38 : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  module.targetConceptTag.replaceAll('_', ' '),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                if (isInProgress)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Tap to continue...",
                      style: TextStyle(
                        color: LiquidTheme.primaryAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isPending)
            const Icon(Icons.chevron_right, color: Colors.white24),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}
