import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/journal_provider.dart';
import '../../providers/user_provider.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({super.key});

  @override
  ConsumerState<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeLanguageProvider);
    final topicsAsync = ref.watch(suggestedTopicsProvider);

    return GlassScaffold(
      title: 'New Entry',
      subtitle: 'Practice writing in $activeLang',
      body: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Topic Suggestions", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: topicsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
                data: (topics) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: topics.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ActionChip(
                    label: Text(topics[index]),
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.white),
                    onPressed: () => _titleController.text = topics[index],
                  ),
                ),
              ),
            ),
             Align(alignment: Alignment.centerRight, child: TextButton(
                onPressed: () => ref.read(journalNotifierProvider.notifier).refreshTopics(activeLang),
                child: const Text("Refresh Topics", style: TextStyle(color: LiquidTheme.primaryAccent, fontSize: 12))
             )),

            const SizedBox(height: 16),
            
            GlassInput(controller: _titleController, hint: "Title / Topic"),
            
            const SizedBox(height: 16),
            
            Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Start writing...",
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  border: InputBorder.none,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            LiquidButton(
              text: "Save & Analyze",
              onTap: () async {
                 if (_contentController.text.isEmpty) return;
                 await ref.read(journalNotifierProvider.notifier).createEntry(
                   _titleController.text.isEmpty ? "Free Write" : _titleController.text,
                   _contentController.text,
                   activeLang
                 );
                 if (context.mounted) context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
