import 'package:flutter/material.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';

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
