import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/journal_provider.dart';
import 'package:intl/intl.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(journalHistoryProvider);

    return GlassScaffold(
      title: 'Journal',
      subtitle: 'Write freely or describe an image',
      showBackButton: false,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'journal_new_entry_fab',
        backgroundColor: LiquidTheme.primaryAccent,
        label: const Text("New Entry", style: TextStyle(color: Colors.white)),
        onPressed: () => context.push('/journal/new'),
      ),
      body: historyAsync.when(
        loading: () => const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
        error: (e, _) =>
            SliverToBoxAdapter(child: Center(child: Text("Error: $e"))),
        data: (entries) {
          if (entries.isEmpty) {
            return const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    "No entries yet. Start writing!",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => context.push('/journal/${entry.id}'),
                  child: GlassCard(
                    padding: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              DateFormat('MMM d').format(entry.createdAt),
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (entry.analysis != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.greenAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Analyzed • Score: ${((entry.analysis!.grammarScore + entry.analysis!.vocabScore) / 2).round()}",
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                ),
              );
            }, childCount: entries.length),
          );
        },
      ),
    );
  }
}
