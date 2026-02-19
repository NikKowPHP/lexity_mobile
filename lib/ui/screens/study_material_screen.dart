import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';

class StudyMaterialScreen extends StatefulWidget {
  final String title;
  final String content; // Text for Read, VideoID for Listen
  final String mode; // 'reading' or 'listening'
  final String moduleId;

  const StudyMaterialScreen({
    super.key, 
    required this.title, 
    required this.content, 
    required this.mode,
    required this.moduleId,
  });

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> {
  YoutubePlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'listening') {
      _videoController = YoutubePlayerController(
        initialVideoId: widget.content,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          forceHD: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReading = widget.mode == 'reading';

    return GlassScaffold(
      title: isReading ? 'Read' : 'Listen',
      subtitle: widget.title,
      body: SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          children: [
            Expanded(
              child: GlassCard(
                padding: isReading ? 24 : 0, // Remove padding for video
                child: isReading 
                    ? SingleChildScrollView(
                        child: Text(
                          widget.content,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            height: 1.6,
                          ),
                        ),
                      )
                    : _buildVideoPlayer(),
              ),
            ),
            const SizedBox(height: 24),
            LiquidButton(
              text: "Write Summary",
              onTap: () {
                _videoController?.pause();
                context.push(
                  '/journal/new?moduleId=${widget.moduleId}&mode=${widget.mode}&topic=${Uri.encodeComponent('Summary: ${widget.title}')}',
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null) {
      return const Center(
        child: Text("Video unavailable", style: TextStyle(color: Colors.white)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: YoutubePlayer(
          controller: _videoController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: LiquidTheme.primaryAccent,
          progressColors: const ProgressBarColors(
            playedColor: LiquidTheme.primaryAccent,
            handleColor: LiquidTheme.secondaryAccent,
          ),
          bottomActions: [
            CurrentPosition(),
            ProgressBar(isExpanded: true),
            RemainingDuration(),
            const PlaybackSpeedButton(),
          ],
        ),
      ),
    );
  }
}
