import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/journal_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/path_provider.dart';
import '../../services/writing_assist_service.dart';
import '../widgets/audio_recorder_widget.dart';
import '../../data/repositories/journal_repository.dart';
import '../../models/writing_aids.dart';
import '../../models/journal_entry.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  final String? moduleId;
  final String? initialMode;
  final String? initialTopic;
  final String? initialImageUrl;

  const JournalEditorScreen({
    super.key,
    this.moduleId,
    this.initialMode,
    this.initialTopic,
    this.initialImageUrl,
  });

  @override
  ConsumerState<JournalEditorScreen> createState() =>
      _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String>? _hints;
  Timer? _stuckTimer;
  Timer? _autoSaveTimer;

  String _getReadableTopic(String? topic) {
    if (topic == 'first-journal') return "My First Journal";
    return topic ?? "Free Write";
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: _getReadableTopic(widget.initialTopic),
    );
    _contentController = TextEditingController();

    _contentController.addListener(_onTextChanged);
    _titleController.addListener(_onTextChanged);

    _restoreDraft();

    if (widget.initialTopic != null) {
      ref
          .read(journalRepositoryProvider)
          .getWritingAids(
            widget.initialTopic!,
            ref.read(activeLanguageProvider),
          );
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final journals = await ref.read(journalHistoryProvider.future);
      final topicTitle = _getReadableTopic(widget.initialTopic);

      final draft = journals.cast<JournalEntry?>().firstWhere(
        (j) =>
            j != null &&
            j.isPending &&
            j.title == topicTitle &&
            j.content.isNotEmpty,
        orElse: () => null,
      );

      if (draft != null && mounted) {
        setState(() {
          _contentController.text = draft.content;
        });
      }
    } catch (e) {
      // No drafts found, start fresh
    }
  }

  void _onTextChanged() {
    _resetStuckTimer();
    _resetAutoSaveTimer();
  }

  void _resetAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () async {
      if (_contentController.text.isEmpty) return;

      final activeLang = ref.read(activeLanguageProvider);
      final topicTitle = _titleController.text.isEmpty
          ? _getReadableTopic(widget.initialTopic)
          : _titleController.text;

      try {
        await ref
            .read(journalRepositoryProvider)
            .createEntry(
              _contentController.text,
              topicTitle,
              activeLang,
              moduleId: widget.moduleId,
            );
      } catch (e) {
        // Silently fail for auto-save
      }
    });
  }

  void _resetStuckTimer() {
    _stuckTimer?.cancel();
    _stuckTimer = Timer(const Duration(seconds: 4), () async {
      if (_contentController.text.isNotEmpty && mounted) {
        setState(() => _hints = ["Lexi is thinking..."]);

        final suggestions = await ref
            .read(writingAssistServiceProvider)
            .generateStuckWriterSuggestions(
              _titleController.text,
              _contentController.text,
              ref.read(activeLanguageProvider),
            );
        _showNudge(suggestions);
      }
    });
  }

  void _showNudge(List<String> hints) {
    if (!mounted) return;
    setState(() => _hints = hints);
    Timer(const Duration(minutes: 2), () {
      if (mounted) setState(() => _hints = null);
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _stuckTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeLanguageProvider);
    final topicsAsync = ref.watch(suggestedTopicsProvider);
    final isAudioMode = widget.initialMode == 'audio_journal';
    final isDescribeMode = widget.initialMode == 'describe_image';

    final aidsAsync = ref.watch(journalAidsProvider(widget.initialTopic ?? ''));

    return LiquidBackground(
      child: GlassScaffold(
        title: isAudioMode ? 'Speak' : 'Write',
        subtitle: 'Practice in $activeLang',
        body: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDescribeMode && widget.initialImageUrl != null) ...[
                const Text(
                  "DESCRIBE THIS IMAGE",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    widget.initialImageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              if (isAudioMode) ...[
                const AudioRecorderWidget(),
                const SizedBox(height: 24),
              ],

              const Text(
                "Topic Suggestions",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: topicsAsync.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 2,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                  error: (_, _) => const SizedBox(),
                  data: (topics) => ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: topics.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) => ActionChip(
                      label: Text(topics[index]),
                      backgroundColor: Colors.white10,
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      onPressed: () => _titleController.text = topics[index],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => ref
                      .read(journalNotifierProvider.notifier)
                      .refreshTopics(activeLang),
                  child: const Text(
                    "Refresh Topics",
                    style: TextStyle(
                      color: LiquidTheme.primaryAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // FIXED: Move NUDGE to the top (above writing aids)
              if (_hints != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GlassCard(
                    padding: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "LEXI'S NUDGE",
                              style: TextStyle(
                                color: LiquidTheme.primaryAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 1.2,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _hints = null),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white24,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._hints!.map(
                          (h) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "• $h",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                ),

              _buildWritingAidsSection(aidsAsync),

              const SizedBox(height: 24),

              const Text(
                "TITLE",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              GlassInput(controller: _titleController, hint: "Entry Title"),

              const SizedBox(height: 16),

              if (!isAudioMode) ...[_buildEditor(), const SizedBox(height: 24)],

              LiquidButton(
                text: "Save & Analyze",
                onTap: () async {
                  if (_contentController.text.isEmpty && !isAudioMode) return;

                  await ref
                      .read(journalNotifierProvider.notifier)
                      .createEntry(
                        _titleController.text.isEmpty
                            ? "Untitled Entry"
                            : _titleController.text,
                        _contentController.text,
                        activeLang,
                        moduleId: widget.moduleId,
                      );

                  if (widget.moduleId != null) {
                    final key = widget.initialMode ?? 'writing';
                    ref
                        .read(pathNotifierProvider.notifier)
                        .updateActivity(widget.moduleId!, key, true);
                  }

                  if (context.mounted && context.canPop()) context.pop();
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWritingAidsSection(AsyncValue<WritingAids> aidsAsync) {
    return aidsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (aids) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "WRITING AIDS",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aids.sentenceStarter.isNotEmpty) ...[
                  const Text(
                    "Try starting with:",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _insertText(aids.sentenceStarter),
                    child: Text(
                      '"${aids.sentenceStarter}..."',
                      style: const TextStyle(
                        color: LiquidTheme.primaryAccent,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  "Useful Vocabulary:",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: aids.suggestedVocab
                      .map(
                        (vocab) => ActionChip(
                          label: Text(vocab),
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          onPressed: () => _insertText(vocab),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return GlassCard(
      padding: 16,
      child: TextField(
        controller: _contentController,
        maxLines: 12,
        style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
        decoration: InputDecoration(
          hintText: "Start writing...",
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
          border: InputBorder.none,
        ),
      ),
    );
  }

  void _insertText(String text) {
    final current = _contentController.text;
    _contentController.text = current.isEmpty ? text : "$current $text";
  }
}
