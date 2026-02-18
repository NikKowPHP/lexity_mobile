import 'package:flutter/material.dart';

import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Journal',
      subtitle: 'Write freely or describe an image',
      body: SliverToBoxAdapter(
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today's Topic", style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              const Text("Describe your favorite childhood memory.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 20),
              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(child: Text("Tap to start writing...", style: TextStyle(color: Colors.white38))),
              ),
              const SizedBox(height: 20),
              LiquidButton(text: "Submit Entry", onTap: () {})
            ],
          ),
        ),
      ),
    );
  }
}
