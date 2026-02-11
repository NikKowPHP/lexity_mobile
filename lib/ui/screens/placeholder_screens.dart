import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';

// 1. Reusable Page Skeleton
class GlassScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget body;
  final Widget? floatingActionButton;

  const GlassScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    // Add padding to bottom to avoid nav bar overlap
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: body,
          ),
          // Spacer for Bottom Navigation Bar
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// 2. Learning Path Page (Modules)
class PathScreen extends StatelessWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Your Path',
      subtitle: 'Module 3: French Basics',
      body: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final isLocked = index > 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                padding: 20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLocked ? Colors.white10 : LiquidTheme.primaryAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isLocked ? Icons.lock_outline : Icons.check,
                        color: isLocked ? Colors.white38 : LiquidTheme.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Unit ${index + 1}: Introductions",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isLocked ? Colors.white38 : Colors.white,
                          ),
                        ),
                        Text(
                          isLocked ? "Complete previous unit" : "In Progress • 80%",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
          childCount: 8,
        ),
      ),
    );
  }
}

// 3. Study/SRS Page
class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Study Deck',
      subtitle: '14 cards due for review',
      body: SliverToBoxAdapter(
        child: Column(
          children: [
            Container(
              height: 400,
              width: double.infinity,
              decoration: BoxDecoration(
                 borderRadius: BorderRadius.circular(30),
                 gradient: const LinearGradient(
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                   colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                 )
              ),
              child: const Center(
                child: Text(
                  "front content...",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ReviewButton(label: "Forgot", color: Colors.red),
                _ReviewButton(label: "Hard", color: Colors.orange),
                _ReviewButton(label: "Good", color: Colors.green),
                _ReviewButton(label: "Easy", color: Colors.blue),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ReviewButton extends StatelessWidget {
  final String label;
  final Color color;
  const _ReviewButton({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

// 4. Journal Page
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

// 5. Progress Page
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Analytics',
      subtitle: 'Your fluency timeline',
      body: SliverToBoxAdapter(
        child: Column(
          children: [
            GlassCard(
              child: SizedBox(
                height: 200,
                child: Center(child: Icon(Icons.show_chart, size: 100, color: LiquidTheme.primaryAccent)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: GlassCard(child: Column(children: [Text("🔥 12", style: TextStyle(fontSize: 24, color: Colors.white)), Text("Streak", style: TextStyle(color: Colors.white54))]))),
                SizedBox(width: 16),
                Expanded(child: GlassCard(child: Column(children: [Text("📚 450", style: TextStyle(fontSize: 24, color: Colors.white)), Text("Words", style: TextStyle(color: Colors.white54))]))),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// 6. Profile Page
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassScaffold(
      title: 'Profile',
      subtitle: 'Manage your settings',
      body: SliverList(
        delegate: SliverChildListDelegate([
          const GlassCard(child: ListTile(leading: Icon(Icons.person, color: Colors.white), title: Text("Account Details", style: TextStyle(color: Colors.white)))),
          const SizedBox(height: 10),
          const GlassCard(child: ListTile(leading: Icon(Icons.language, color: Colors.white), title: Text("Target Language", style: TextStyle(color: Colors.white)))),
          const SizedBox(height: 10),
          const GlassCard(child: ListTile(leading: Icon(Icons.notifications, color: Colors.white), title: Text("Notifications", style: TextStyle(color: Colors.white)))),
          const SizedBox(height: 30),
          LiquidButton(
            text: "Sign Out",
            onTap: () => ref.read(authProvider.notifier).logout(),
            isLoading: false,
          ),
        ]),
      ),
    );
  }
}
