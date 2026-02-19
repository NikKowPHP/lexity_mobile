import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/translator_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/srs_provider.dart';
import '../../models/translation_result.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';

class TranslatorScreen extends ConsumerStatefulWidget {
  final bool isBubbleMode;
  const TranslatorScreen({super.key, this.isBubbleMode = false});

  @override
  ConsumerState<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends ConsumerState<TranslatorScreen> {
  final _inputController = TextEditingController();
  String? _sourceLang;
  String? _targetLang;
  static const platform = MethodChannel('com.lexity.app/bubbles');

  @override
  void initState() {
    super.initState();
      Future.microtask(() {
        final profile = ref.read(userProfileProvider).value;
        setState(() {
          _sourceLang = profile?.nativeLanguage ?? "English";
          _targetLang = profile?.defaultTargetLanguage ?? "Spanish";
        });
      });
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _inputController.text = data!.text!;
      });
    }
  }

  void _discardText() {
    setState(() {
      _inputController.clear();
    });
  }

  Future<void> _enableBubbleMode() async {
    if (!Platform.isAndroid) return;
    PermissionStatus status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Notifications are needed for Bubble mode", style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
    try {
      await platform.invokeMethod('showBubble');
    } on PlatformException catch (e) {
      debugPrint("Failed to launch bubble: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(translatorProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    final List<String> availableLanguages = profileAsync.maybeWhen(
      data: (p) => {
        if (p.nativeLanguage != null && p.nativeLanguage!.isNotEmpty) p.nativeLanguage!,
        ...p.languageProfiles.map((lp) => lp.language).where((l) => l.isNotEmpty),
        if (p.defaultTargetLanguage.isNotEmpty) p.defaultTargetLanguage,
      }.toList(),
      orElse: () => ["English", "Spanish", "French", "German"],
    );

    final effectiveSource = availableLanguages.contains(_sourceLang) ? _sourceLang! : availableLanguages.first;
    final effectiveTarget = availableLanguages.contains(_targetLang) ? _targetLang! : (availableLanguages.length > 1 ? availableLanguages[1] : availableLanguages.first);

    Widget buildMainContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: LiquidDropdown<String>(label: "From", value: effectiveSource, items: availableLanguages, onChanged: (val) => setState(() => _sourceLang = val))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: IconButton(onPressed: _swapLanguages, icon: const Icon(Icons.swap_horiz, color: Colors.white54))),
              Expanded(child: LiquidDropdown<String>(label: "To", value: effectiveTarget, items: availableLanguages, onChanged: (val) => setState(() => _targetLang = val))),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              GlassCard(
                padding: 16,
                child: TextField(
                  controller: _inputController,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 18, color: Colors.white, height: 1.5),
                  decoration: const InputDecoration(hintText: "Enter text...", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Positioned(top: 12, right: 12, child: _inputController.text.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: _discardText)
                : IconButton(icon: const Icon(Icons.content_paste, color: Colors.white38), onPressed: _pasteFromClipboard)),
            ],
          ),
          const SizedBox(height: 16),
          LiquidButton(
            text: "Translate",
            isLoading: state.isTranslating,
            onTap: () {
              if (_inputController.text.isNotEmpty) {
                ref.read(translatorProvider.notifier).runTranslation(_inputController.text, effectiveSource, effectiveTarget);
              }
            },
          ),
          if (state.fullTranslation.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text("TRANSLATION", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            GlassCard(
              padding: 20,
              child: Text(state.fullTranslation, style: const TextStyle(fontSize: 18, color: Colors.white, height: 1.5)),
            ),
          ],
        ],
      );
    }

    Widget buildBreakdownContent() {
      if (state.isBreakingDown) {
        return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.white24)));
      }
      if (state.segments.isEmpty) {
        return Center(
          child: Opacity(
            opacity: 0.3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                const Text("Analysis will appear here", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SENTENCE BREAKDOWN", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ...state.segments.map((seg) => _SegmentCard(segment: seg, targetLanguage: effectiveTarget)),
        ],
      );
    }

    return GlassScaffold(
      title: 'Translator',
      subtitle: 'Real-time AI analysis',
      showBackButton: false,
      floatingActionButton: (Platform.isAndroid && !widget.isBubbleMode)
        ? Padding(padding: const EdgeInsets.only(bottom: 80), child: FloatingActionButton(backgroundColor: LiquidTheme.primaryAccent, onPressed: _enableBubbleMode, child: const Icon(Icons.open_in_new, color: Colors.white)))
        : null,
      body: SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: isDesktop 
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: buildMainContent()), const SizedBox(width: 40), Expanded(flex: 4, child: buildBreakdownContent())])
            : Column(children: [buildMainContent(), const SizedBox(height: 40), buildBreakdownContent()]),
        ),
      ),
    );
  }
}

class _SegmentCard extends ConsumerStatefulWidget {
  final TranslationSegment segment;
  final String targetLanguage;
  const _SegmentCard({required this.segment, required this.targetLanguage});

  @override
  ConsumerState<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends ConsumerState<_SegmentCard> {
  bool _isAdding = false;
  bool _isAdded = false;

  Future<void> _handleAddToDeck() async {
    setState(() => _isAdding = true);
    final success = await ref.read(srsProvider.notifier).addToDeckFromTranslation(
          front: widget.segment.source,
          back: widget.segment.translation,
          language: widget.targetLanguage.toLowerCase(),
          explanation: widget.segment.explanation,
        );

    if (mounted) {
      setState(() {
        _isAdding = false;
        if (success) _isAdded = true;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Study Deck", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)), backgroundColor: LiquidTheme.primaryAccent, behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.segment.source, style: const TextStyle(color: Colors.white38, fontSize: 14))),
                IconButton(
                  onPressed: (_isAdded || _isAdding) ? null : _handleAddToDeck,
                  icon: _isAdding
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))
                      : Icon(_isAdded ? Icons.check_circle : Icons.add_circle, color: _isAdded ? Colors.greenAccent : LiquidTheme.primaryAccent, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(widget.segment.translation, style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.segment.explanation, style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
