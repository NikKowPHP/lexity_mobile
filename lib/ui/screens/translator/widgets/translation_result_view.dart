import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/liquid_components.dart';
import '../../../widgets/tutor_chat_dialog.dart';
import '../../../../providers/connectivity_provider.dart';
import '../../../../services/ai_service.dart';

/// Displays the translation result with explain button.
class TranslationResultView extends ConsumerWidget {
  final String fullTranslation;
  final String inputText;
  final String targetLanguage;
  final VoidCallback? onExplainWithLexi;

  const TranslationResultView({
    super.key,
    required this.fullTranslation,
    required this.inputText,
    required this.targetLanguage,
    this.onExplainWithLexi,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TRANSLATION",
          style: TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: 20,
          child: Text(
            fullTranslation,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: isOnline ? 1.0 : 0.5,
          child: Column(
            children: [
              LiquidButton(
                text: "Explain Nuances with Lexi",
                onTap: isOnline
                    ? () => showDialog(
                        context: context,
                        builder: (c) => TutorChatDialog(
                          title: "Translation Analysis",
                          onSendMessage: (msg, history) => ref
                              .read(aiServiceProvider)
                              .getTutorResponse(
                                endpoint: '/api/ai/translator-tutor-chat',
                                context: {
                                  'sourceText': inputText,
                                  'fullTranslation': fullTranslation,
                                  'targetLanguage': targetLanguage,
                                },
                                chatHistory: history,
                              ),
                        ),
                      )
                    : () {},
              ),
              if (!isOnline)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    "Requires internet connection",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
