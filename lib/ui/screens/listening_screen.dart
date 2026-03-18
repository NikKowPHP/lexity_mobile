import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/listening_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/path_provider.dart';
import '../../models/listening_models.dart';
import '../../models/writing_aids.dart';

class ListeningScreen extends ConsumerStatefulWidget {
  final String? moduleId;
  
  const ListeningScreen({super.key, this.moduleId});

  @override
  ConsumerState<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends ConsumerState<ListeningScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _responseController = TextEditingController();
  YoutubePlayerController? _videoController;
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Pause video when switching tabs
    _tabController.addListener(() {
      if (_tabController.index == 1 && _videoController != null) {
        _videoController!.pause();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _responseController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _insertText(String text) {
    final currentText = _responseController.text;
    if (currentText.isEmpty) {
      _responseController.text = text;
    } else {
      _responseController.text = "$currentText $text";
    }
    _responseController.selection = TextSelection.fromPosition(TextPosition(offset: _responseController.text.length));
  }

  @override
  Widget build(BuildContext context) {
    final exerciseAsync = ref.watch(listeningExerciseProvider);
    final tasksAsync = ref.watch(listeningTaskProvider);
    final aidsAsync = ref.watch(listeningAidsProvider);
    final activeLang = ref.watch(activeLanguageProvider);

    return GlassScaffold(
      title: 'Listen & Write',
      subtitle: 'Comprehension Practice',
      body: exerciseAsync.when(
        loading: () => const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (e, _) => SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text("Error loading exercise: $e", style: const TextStyle(color: Colors.white))),
        ),
        data: (exercise) {
          // Initialize Video Controller once
          _videoController ??= YoutubePlayerController(
              initialVideoId: exercise.videoId,
              flags: const YoutubePlayerFlags(
                autoPlay: false,
                mute: false,
                forceHD: true,
              ),
            );

          // Auto-generate tasks
          if (tasksAsync.value == null && !tasksAsync.isLoading && !tasksAsync.hasError) {
             Future.microtask(() => 
               ref.read(listeningTaskProvider.notifier).generate(exercise.id)
             );
          }

          return SliverFillRemaining(
            hasScrollBody: true,
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: LiquidTheme.primaryAccent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "Watch"),
                    Tab(text: "Write"),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWatchTab(exercise),
                      _buildWriteTab(tasksAsync, aidsAsync, activeLang, exercise),
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

  Widget _buildWatchTab(ListeningExercise exercise) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // VIDEO PLAYER
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: YoutubePlayer(
              controller: _videoController!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: LiquidTheme.primaryAccent,
              progressColors: const ProgressBarColors(
                playedColor: LiquidTheme.primaryAccent,
                handleColor: LiquidTheme.secondaryAccent,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          GlassCard(
            padding: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                if (exercise.source != null) ...[
                  const SizedBox(height: 4),
                  Text("Source: ${exercise.source}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white54, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text("Watch the video carefully. You will be asked to summarize it in the next tab.", style: TextStyle(color: Colors.white70, fontSize: 13))),
                  ],
                )
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          LiquidButton(
            text: "Start Writing",
            onTap: () {
               _videoController?.pause();
               _tabController.animateTo(1);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWriteTab(
    AsyncValue<ListeningTasksResponse?> tasksAsync, 
    AsyncValue<WritingAids?> aidsAsync,
    String lang,
    ListeningExercise exercise
  ) {
    if (tasksAsync.isLoading) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Generating writing tasks...", style: TextStyle(color: Colors.white54)),
        ],
      ));
    }

    final tasks = tasksAsync.value;
    if (tasks == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // 1. COMPREHENSION TASK
          GlassCard(
            padding: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Topic: ${tasks.summary.title}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                Text(tasks.summary.prompt, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text("Questions to answer:", style: TextStyle(color: LiquidTheme.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 4),
                       Text(tasks.comprehension.prompt, style: const TextStyle(fontSize: 13, color: Colors.white70, fontStyle: FontStyle.italic)),
                     ],
                   ),
                )
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // 2. WRITING AIDS
          aidsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(16.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
            error: (_,_) => const SizedBox(),
            data: (aids) {
              if (aids == null) return const SizedBox();
              return GlassCard(
                padding: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Sentence Starter", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _insertText(aids.sentenceStarter),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('"${aids.sentenceStarter}"', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white))),
                            const Text("Use this", style: TextStyle(color: LiquidTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("Vocabulary to Try", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: aids.suggestedVocab.map((vocab) => ActionChip(
                        label: Text(vocab),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onPressed: () => _insertText(vocab),
                      )).toList(),
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
                hintText: "Summarize the video and answer the questions...",
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please write a bit more!")));
      return;
    }

    setState(() => _isSubmitting = true);
    _videoController?.pause();

    try {
      final tasks = ref.read(listeningTaskProvider).value!;
      final lang = ref.read(activeLanguageProvider);
      final exercise = ref.read(listeningExerciseProvider).value!;

      // 1. Submit Journal
      final newEntryId = await ref.read(journalNotifierProvider.notifier).createEntry(
        tasks.summary.title,
        _responseController.text,
        lang,
        moduleId: widget.moduleId,
      );

      // 2. Mark Activity Complete (and link the specific listening exercise)
      if (widget.moduleId != null) {
        await ref.read(pathNotifierProvider.notifier).updateActivity(
          widget.moduleId!, 
          'listening', 
          true,
          {'listeningExerciseId': exercise.id}
        );
      }

      if (mounted && newEntryId != null) {
        context.pushReplacement('/journal/$newEntryId');
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission failed: $e")));
         setState(() => _isSubmitting = false);
      }
    }
  }
}
      