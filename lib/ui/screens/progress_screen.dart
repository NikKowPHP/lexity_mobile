import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/liquid_theme.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/analytics_provider.dart';
import '../widgets/analytics_components.dart';
import '../../providers/user_provider.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsDataProvider);
    final goalProgressAsync = ref.watch(goalProgressProvider);
    final heatmapAsync = ref.watch(activityHeatmapProvider);
    final userProfile = ref.watch(userProfileProvider).value;

    return GlassScaffold(
      title: 'Analytics',
      subtitle: 'Your fluency timeline',
      showBackButton: false,
      body: analyticsAsync.when(
        loading: () => const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
        error: (e, _) => SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              "Error: $e",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        data: (analytics) {
          final hasData = analytics.totalEntries > 0;

          if (!hasData) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: GlassCard(
                  padding: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.show_chart,
                        size: 60,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "No Progress Yet",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Write your first journal entry to start tracking.",
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 24),
                      LiquidButton(
                        text: "Start Writing",
                        onTap: () {} /* Nav to journal */,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SliverList(
            delegate: SliverChildListDelegate(
              [
                // 1. Dashboard Summary
                Row(
                  children: [
                    Expanded(
                      child: DashboardSummaryCard(
                        label: "Total Entries",
                        value: analytics.totalEntries.toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardSummaryCard(
                        label: "Avg. Score",
                        value: "${analytics.averageScore.toStringAsFixed(1)}%",
                      ),
                    ),
                  ],
              ),
                const SizedBox(height: 12),
                if (userProfile != null)
                  DashboardSummaryCard(
                    label: "Streak",
                    value: "${userProfile.currentStreak} Days",
                    subValue: "Longest: ${userProfile.longestStreak}",
                  ),
              
                const SizedBox(height: 24),

                // 2. Weekly Goal & Study Time
                if (goalProgressAsync.hasValue)
                  GoalProgressWidget(progress: goalProgressAsync.value!),

                const SizedBox(height: 12),

                GlassCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Time Studied Today",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Includes writing & review",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${(analytics.studyTimeToday / 60).round()} min",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Proficiency Chart (PRO only logic can be added here)
                ProficiencyLineChart(
                  history: analytics.proficiencyOverTime,
                  prediction: analytics.predictedProficiencyOverTime,
                ),

                const SizedBox(height: 24),

                // 4. SRS Forecast
                SrsForecastWidget(counts: analytics.dueCounts),

                const SizedBox(height: 24),

                // 5. Heatmap
                if (heatmapAsync.hasValue)
                  SimpleHeatmap(data: heatmapAsync.value!),

                const SizedBox(height: 40),
              ].animate(interval: 100.ms).fadeIn().slideY(begin: 0.1, end: 0),
            ),
          );
        },
      ),
    );
  }
}
