import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/path_provider.dart';
import '../../models/learning_module.dart';
import '../../providers/user_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/user_profile.dart';
import '../../models/journal_entry.dart';

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
          final profile = ref.watch(userProfileProvider).value;
          final onboardingStep = ref.watch(onboardingProvider);
          
          if (profile != null && !profile.onboardingCompleted) {
             final journals = ref.watch(journalHistoryProvider).value ?? [];
             return SliverToBoxAdapter(
               child: Padding(
                 padding: const EdgeInsets.all(20),
                 child: Column(
                   children: [
                     const Text("WELCOME TO LEXITY", style: TextStyle(color: LiquidTheme.primaryAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                     const SizedBox(height: 8),
                     const Text("Complete these steps to unlock your path", style: TextStyle(color: Colors.white70, fontSize: 13)),
                     const SizedBox(height: 32),
                     _buildOnboardingTimeline(profile, journals),
                     const SizedBox(height: 32),
                     if (onboardingStep == OnboardingStep.firstJournal)
                        LiquidButton(text: "Start First Journal", onTap: () => context.push('/path/read')),
                   ],
                 ),
               ),
             );
          }

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

Widget _buildOnboardingTimeline(UserProfile profile, List<JournalEntry> journals) {
  final step1Complete = profile.nativeLanguage != null && profile.nativeLanguage!.isNotEmpty;
  final step2Complete = journals.isNotEmpty;
  final step3Complete = journals.isNotEmpty && journals.first.analysis != null;
  final step4Complete = profile.onboardingCompleted;

  return Column(
    children: [
      _TimelineNode(title: "1. Language Setup", isDone: step1Complete),
      _TimelineNode(title: "2. First Journal Entry", isDone: step2Complete, isActive: step1Complete),
      _TimelineNode(title: "3. AI Analysis", isDone: step3Complete, isActive: step2Complete),
      _TimelineNode(title: "4. Personalized Path", isDone: step4Complete, isActive: step3Complete),
    ],
  );
}

class _TimelineNode extends StatelessWidget {
  final String title;
  final bool isDone;
  final bool isActive;

  const _TimelineNode({required this.title, required this.isDone, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDone ? Colors.greenAccent : (isActive ? LiquidTheme.primaryAccent.withValues(alpha: 0.2) : Colors.white10),
              shape: BoxShape.circle,
              border: isDone ? null : Border.all(color: isActive ? LiquidTheme.primaryAccent : Colors.white24),
            ),
            child: isDone ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              color: isDone ? Colors.white : (isActive ? Colors.white70 : Colors.white24),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
