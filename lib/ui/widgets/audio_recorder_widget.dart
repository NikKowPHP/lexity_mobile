import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_service.dart';
import '../../providers/user_provider.dart';
import 'liquid_components.dart';

enum RecordingStatus { idle, recording, paused, stopped }

class AudioRecorderWidget extends ConsumerStatefulWidget {
  const AudioRecorderWidget({super.key});

  @override
  ConsumerState<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends ConsumerState<AudioRecorderWidget> {
  RecordingStatus status = RecordingStatus.idle;
  int _seconds = 0;
  Timer? _timer;
  List<String>? _hints;

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _toggleRecording() {
    setState(() {
      if (status == RecordingStatus.idle || status == RecordingStatus.stopped) {
        status = RecordingStatus.recording;
        _seconds = 0;
        _startTimer();
      } else if (status == RecordingStatus.recording) {
        status = RecordingStatus.paused;
        _stopTimer();
      } else if (status == RecordingStatus.paused) {
        status = RecordingStatus.recording;
        _startTimer();
      }
    });
  }

  Future<void> _getSpeakerHint() async {
    // Placeholder implementation for audio slicing
    // In a real app, this would use 'record' or 'flutter_sound'
    // and potentially 'ffmpeg_kit_flutter' for slicing.
    
    // Simulate API call
    final hints = await ref.read(aiServiceProvider).getStuckSpeakerSuggestions(
      [0, 1, 2, 3], // Mocked bytes
      ref.read(activeLanguageProvider)
    );
    
    _showHintsOverlay(hints);
  }

  void _showHintsOverlay(List<String> hints) {
    if (!mounted) return;
    setState(() => _hints = hints);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          padding: 24,
          child: Column(
            children: [
              Text(
                _formatTime(_seconds),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 12),
              Text(
                status == RecordingStatus.recording ? "Recording..." : (status == RecordingStatus.paused ? "Paused" : "Ready"),
                style: TextStyle(color: status == RecordingStatus.recording ? Colors.redAccent : Colors.white54),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: status == RecordingStatus.recording ? Colors.redAccent.withValues(alpha: 0.1) : Colors.white10,
                    border: Border.all(color: status == RecordingStatus.recording ? Colors.redAccent : Colors.white24, width: 2),
                  ),
                  child: Icon(
                    status == RecordingStatus.recording ? Icons.pause : Icons.mic,
                    color: status == RecordingStatus.recording ? Colors.redAccent : Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        if (status == RecordingStatus.paused)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton.icon(
              onPressed: _getSpeakerHint,
              icon: const Icon(Icons.lightbulb, color: Colors.amber),
              label: const Text("Get a hint from Lexi", style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white10),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
        if (_hints != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Lexi suggests:", style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.white54), onPressed: () => setState(() => _hints = null)),
                    ],
                  ),
                  ..._hints!.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text("• $h", style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  )),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
