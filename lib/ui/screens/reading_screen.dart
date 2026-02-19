import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/reading_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/path_provider.dart';
import '../../models/reading_models.dart';
import '../../models/writing_aids.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  final String? moduleId;
  
  const ReadingScreen({super.key, this.moduleId});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _responseController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  void _insertText(String text) {
    final currentText = _responseController.text;
    if (currentText.isEmpty) {
      _responseController.text = text;
    } else {
      _responseController.text = "$currentText $text";
    }
    // Move cursor to end
    _responseController.selection = TextSelection.fromPosition(
      TextPosition(offset: _responseController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final materialAsync = ref.watch(readingMaterialProvider);
    final tasksAsync = ref.watch(readingTaskProvider);
    final aidsAsync = ref.watch(readingAidsProvider); // Watch the new provider
    final activeLang = ref.watch(activeLanguageProvider);

    return GlassScaffold(
      title: 'Read & Write',
      subtitle: 'Comprehension Practice',
      body: materialAsync.when(
        loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SliverFillRemaining(child: Center(child: Text("Error: $e"))),
        data: (material) {
          // Auto-generate tasks if not yet loaded
          if (tasksAsync.value == null && !tasksAsync.isLoading && !tasksAsync.hasError) {
             Future.microtask(() => 
               ref.read(readingTaskProvider.notifier).generate(material.content, activeLang, material.level)
             );
          }

          return SliverFillRemaining(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: LiquidTheme.primaryAccent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: "Reading"),
                    Tab(text: "Writing Task"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: READING MATERIAL
                      _buildReadingTab(material),

                      // TAB 2: WRITING TASK & AIDS
                      _buildWritingTab(
                        tasksAsync,
                        aidsAsync,
                        activeLang,
                        material,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadingTab(ReadingMaterial material) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(material.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            if (material.source != null)
              Text("Source: ${material.source}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 20),
            Text(
              material.content,
              style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            LiquidButton(
              text: "Start Writing",
              onTap: () => _tabController.animateTo(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWritingTab(
    AsyncValue<ReadingTasksResponse?> tasksAsync,
    AsyncValue<WritingAids?> aidsAsync,
    String lang,
    ReadingMaterial material,
  ) {
    if (tasksAsync.isLoading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("AI is generating your tasks...", style: TextStyle(color: Colors.white54)),
        ],
      ));
    }

    final tasks = tasksAsync.value;
    if (tasks == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 1. TASK INFO
          GlassCard(
            padding: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Topic: ${tasks.summary.title}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(tasks.summary.prompt, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // 2. WRITING AIDS (Sentence Starter & Vocab)
          aidsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, stack) => const SizedBox(),
            data: (aids) {
              if (aids == null) return const SizedBox();
              return GlassCard(
                padding: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sentence Starter
                    const Text(
                      "Sentence Starter",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '"${aids.sentenceStarter}"',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => _insertText(aids.sentenceStarter),
                              child: const Text(
                                "Use this",
                                style: TextStyle(
                                  color: LiquidTheme.primaryAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Vocabulary Chips
                    const Text(
                      "Vocabulary to Try",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: aids.suggestedVocab
                          .map(
                            (vocab) => ActionChip(
                              label: Text(vocab),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              labelStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onPressed: () => _insertText(vocab),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }
          ),

          const SizedBox(height: 16),

          // 3. EDITOR
          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              controller: _responseController,
              maxLines: null,
              expands: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Start writing about \"${tasks.summary.title}\"...",
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                border: InputBorder.none,
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          LiquidButton(
            text: "Submit for Analysis",
            onTap: () async {
              if (_responseController.text.length < 10) return;

              // Submit Journal
              final journalNotifier = ref.read(journalNotifierProvider.notifier);
              await journalNotifier.createEntry(
                tasks.summary.title,
                _responseController.text,
                lang,
                moduleId: widget.moduleId,
              );

              // Mark Complete
              if (widget.moduleId != null) {
                ref.read(pathNotifierProvider.notifier).updateActivity(
                  widget.moduleId!, 
                  'reading', 
                  true,
                );
              }

              if (mounted) {
                context.pop();
              }
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
