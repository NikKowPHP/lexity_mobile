import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/journal_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/path_provider.dart';
import '../../services/ai_service.dart';
import '../widgets/audio_recorder_widget.dart';
import 'dart:async';

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
  ConsumerState<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  List<String>? _hints;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialTopic ?? "Free Write",
    );
    _contentController = TextEditingController();
    _contentController.addListener(_resetStuckTimer);
  }

  Timer? _stuckTimer;
  void _resetStuckTimer() {
    _stuckTimer?.cancel();
    _stuckTimer = Timer(const Duration(seconds: 7), () async {
      if (_contentController.text.isNotEmpty && mounted) {
        final suggestions = await ref.read(aiServiceProvider).generateStuckWriterSuggestions(
          _titleController.text, 
          _contentController.text, 
          ref.read(activeLanguageProvider)
        );
        _showNudge(suggestions);
      }
    });
  }

  void _showNudge(List<String> hints) {
    if (!mounted) return;
    setState(() => _hints = hints);
    // Auto-hide after 2 minutes to match web
    Timer(const Duration(minutes: 2), () {
      if (mounted) setState(() => _hints = null);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _stuckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeLang = ref.watch(activeLanguageProvider);
    final topicsAsync = ref.watch(suggestedTopicsProvider);
    final isAudioMode = widget.initialMode == 'audio_journal';
    final isDescribeMode = widget.initialMode == 'describe_image';

    return GlassScaffold(
      title: isAudioMode ? 'Speak' : 'Write',
      subtitle: 'Practice in $activeLang',
      body: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE PROMPT (For Describe Image mode)
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

            // 2. ADAPTIVE INPUT (Audio vs Text)
            if (isAudioMode) ...[
              const AudioRecorderWidget(),
              const SizedBox(height: 24),
            ],

            const Text("Topic Suggestions", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
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
             Align(alignment: Alignment.centerRight, child: TextButton(
                onPressed: () => ref.read(journalNotifierProvider.notifier).refreshTopics(activeLang),
                child: const Text("Refresh Topics", style: TextStyle(color: LiquidTheme.primaryAccent, fontSize: 12))
             )),

            const SizedBox(height: 16),
            
            if (_hints != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Need a nudge?", style: TextStyle(color: LiquidTheme.primaryAccent, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.white54), onPressed: () => setState(() => _hints = null)),
                        ],
                      ),
                      ..._hints!.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text("• $h", style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      )),
                    ],
                  ),
                ),
              ),
            
            GlassInput(controller: _titleController, hint: "Title / Topic"),
            
            const SizedBox(height: 16),
            
            if (!isAudioMode) ...[
              _buildTextInterface(),
              const SizedBox(height: 24),
            ],

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
                  // Mark module activity done
                  final key = widget.initialMode ?? 'writing';
                  ref
                      .read(pathNotifierProvider.notifier)
                      .updateActivity(widget.moduleId!, key, true);
                }

                if (context.mounted && context.canPop()) context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInterface() {
    return Container(
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
    );
  }
}
