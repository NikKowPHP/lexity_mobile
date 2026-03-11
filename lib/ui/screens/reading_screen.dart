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
  bool _isSubmitting = false;
  
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
    _responseController.selection = TextSelection.fromPosition(
      TextPosition(offset: _responseController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final materialAsync = ref.watch(readingMaterialProvider);
    final tasksAsync = ref.watch(readingTaskProvider);
    final aidsAsync = ref.watch(readingAidsProvider);
    final activeLang = ref.watch(activeLanguageProvider);

    return GlassScaffold(
      title: 'Read & Write',
      subtitle: 'Comprehension Practice',
      body: materialAsync.when(
        // FIX: Wrap Center in SliverFillRemaining
        loading: () => const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
        // FIX: Wrap Center in SliverFillRemaining
        error: (e, _) =>
            SliverFillRemaining(child: Center(child: Text("Error: $e"))),
        data: (material) {
          if (tasksAsync.value == null && !tasksAsync.isLoading && !tasksAsync.hasError) {
             Future.microtask(() => 
               ref.read(readingTaskProvider.notifier).generate(material.content, activeLang, material.level)
             );
          }

          // FIX: Wrap NestedScrollView in SliverFillRemaining
          return SliverFillRemaining(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: LiquidTheme.primaryAccent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      tabs: const [
                        Tab(text: "Reading"),
                        Tab(text: "Writing Task"),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildReadingTab(material),
                  _buildWritingTab(tasksAsync, aidsAsync, activeLang, material),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadingTab(ReadingMaterial material) {
    return SingleChildScrollView(
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
    ReadingMaterial material
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
      child: Column(
        children: [
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
            error: (_, _) => const SizedBox(),
            data: (aids) {
              if (aids == null) return const SizedBox();
              return GlassCard(
                padding: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Sentence Starter",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _insertText(aids.sentenceStarter),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '"${aids.sentenceStarter}"',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Text(
                              "Use this",
                              style: TextStyle(
                                color: LiquidTheme.primaryAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
            text: _isSubmitting ? "Analyzing..." : "Submit for Analysis",
            isLoading: _isSubmitting,
            onTap: _submitExercise,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _submitExercise() async {
    if (_responseController.text.length < 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please write a bit more!")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final tasks = ref.read(readingTaskProvider).value!;
      final lang = ref.read(activeLanguageProvider);
      final material = ref.read(readingMaterialProvider).value!;

      final newEntryId = await ref
          .read(journalNotifierProvider.notifier)
          .createEntry(
            tasks.summary.title,
            _responseController.text,
            lang,
            moduleId: widget.moduleId,
          );

      if (widget.moduleId != null) {
        await ref.read(pathNotifierProvider.notifier).updateActivity(
          widget.moduleId!,
          'reading',
          true,
          {'materialId': material.id}
        );
      }

      if (mounted && newEntryId != null) {
        context.pushReplacement('/journal/$newEntryId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Submission failed: $e")));
        setState(() => _isSubmitting = false);
      }
    }
  }
}
