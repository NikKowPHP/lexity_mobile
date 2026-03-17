import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/analysis_widgets.dart';
import '../widgets/tutor_chat_dialog.dart';
import '../../providers/journal_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../services/ai_service.dart';

class JournalDetailScreen extends ConsumerWidget {
  final String journalId;
  const JournalDetailScreen({super.key, required this.journalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(journalDetailProvider(journalId));

    return entryAsync.when(
      loading: () => const Scaffold(
        body: LiquidBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Scaffold(
        body: LiquidBackground(child: Center(child: Text("Error: $e"))),
      ),
      data: (entry) {
        return GlassScaffold(
          title: entry.title,
          subtitle: entry.createdAt.toString().split(' ')[0],
          floatingActionButton: entry.isPending
              ? null
              : FloatingActionButton.extended(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text("Ask Lexi"),
                  backgroundColor: LiquidTheme.primaryAccent,
                  onPressed: () => showDialog(
                    context: context,
                    builder: (c) => TutorChatDialog(
                      title: "Discussing: ${entry.title}",
                      onSendMessage: (msg, history) => ref
                          .read(aiServiceProvider)
                          .getTutorResponse(
                            endpoint: '/api/ai/journal-tutor-chat',
                            context: {'journalId': entry.id},
                            chatHistory: history,
                          ),
                    ),
                  ),
                ),
          body: SliverList(
            delegate: SliverChildListDelegate([
              GlassCard(
                padding: 20,
                child: Text(
                  entry.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (entry.analysis != null) ...[
                const Text(
                  "AI ANALYSIS",
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                AnalysisScoreCard(analysis: entry.analysis!),
                const SizedBox(height: 24),

                if (entry.analysis!.feedback.isNotEmpty) ...[
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: LiquidTheme.primaryAccent,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Feedback",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.analysis!.feedback,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (entry.analysis!.mistakes.isNotEmpty) ...[
                  const Text(
                    "CORRECTIONS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MistakesList(mistakes: entry.analysis!.mistakes),
                ],
              ] else ...[
                Consumer(
                  builder: (context, ref, _) {
                    final isOnline = ref.watch(connectivityProvider);
                    return Center(
                      child: Column(
                        children: [
                          if (!isOnline)
                            GlassCard(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.cloud_off,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Analysis queued. Waiting for network...",
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Analysis in progress...",
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 40),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ref
                        .read(journalNotifierProvider.notifier)
                        .deleteEntry(entry.id);
                    if (context.canPop()) context.pop();
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    "Delete Entry",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        );
      },
    );
  }
}
