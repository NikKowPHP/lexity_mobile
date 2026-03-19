import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/translator_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import 'translator/widgets/language_selector_bar.dart';
import 'translator/widgets/translation_result_view.dart';
import 'translator/widgets/segment_card.dart';

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
              content: Text(
                "Notifications are needed for Bubble mode",
                style: TextStyle(color: Colors.white),
              ),
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
        if (p.nativeLanguage != null && p.nativeLanguage!.isNotEmpty)
          p.nativeLanguage!,
        ...p.languageProfiles
            .map((lp) => lp.language)
            .where((l) => l.isNotEmpty),
        if (p.defaultTargetLanguage.isNotEmpty) p.defaultTargetLanguage,
      }.toList(),
      orElse: () => ["English", "Spanish", "French", "German"],
    );

    final effectiveSource = availableLanguages.contains(_sourceLang)
        ? _sourceLang!
        : availableLanguages.first;
    final effectiveTarget = availableLanguages.contains(_targetLang)
        ? _targetLang!
        : (availableLanguages.length > 1
              ? availableLanguages[1]
              : availableLanguages.first);

    Widget buildMainContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LanguageSelectorBar(
            sourceLang: effectiveSource,
            targetLang: effectiveTarget,
            availableLanguages: availableLanguages,
            onSourceChanged: (val) => setState(() => _sourceLang = val),
            onTargetChanged: (val) => setState(() => _targetLang = val),
            onSwap: _swapLanguages,
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              GlassCard(
                padding: 16,
                child: TextField(
                  controller: _inputController,
                  maxLines: 6,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: "Enter text...",
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _inputController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38),
                        onPressed: _discardText,
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.content_paste,
                          color: Colors.white38,
                        ),
                        onPressed: _pasteFromClipboard,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LiquidButton(
            text: "Translate",
            isLoading: state.isTranslating,
            onTap: () {
              if (_inputController.text.isNotEmpty) {
                ref
                    .read(translatorProvider.notifier)
                    .runTranslation(
                      _inputController.text,
                      effectiveSource,
                      effectiveTarget,
                    );
              }
            },
          ),
          if (state.fullTranslation.isNotEmpty) ...[
            const SizedBox(height: 32),
            TranslationResultView(
              fullTranslation: state.fullTranslation,
              inputText: _inputController.text,
              targetLanguage: effectiveTarget,
            ),
          ],
        ],
      );
    }

    Widget buildBreakdownContent() {
      if (state.isBreakingDown) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: Colors.white24),
          ),
        );
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
                const Text(
                  "Analysis will appear here",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SENTENCE BREAKDOWN",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...state.segments.map(
            (seg) => SegmentCard(segment: seg, targetLanguage: effectiveTarget),
          ),
        ],
      );
    }

    return GlassScaffold(
      title: 'Translator',
      subtitle: 'Real-time AI analysis',
      showBackButton: false,
      floatingActionButton: (Platform.isAndroid && !widget.isBubbleMode)
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton(
                heroTag: 'translator_bubble_fab',
                backgroundColor: LiquidTheme.primaryAccent,
                onPressed: _enableBubbleMode,
                child: const Icon(Icons.open_in_new, color: Colors.white),
              ),
            )
          : null,
      body: SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: buildMainContent()),
                    const SizedBox(width: 40),
                    Expanded(flex: 4, child: buildBreakdownContent()),
                  ],
                )
              : Column(
                  children: [
                    buildMainContent(),
                    const SizedBox(height: 40),
                    buildBreakdownContent(),
                  ],
                ),
        ),
      ),
    );
  }
}
