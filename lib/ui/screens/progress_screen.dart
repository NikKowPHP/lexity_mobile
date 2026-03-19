import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/liquid_components.dart';
import '../widgets/glass_scaffold.dart';
import '../../providers/analytics_provider.dart';
import '../widgets/analytics_components.dart';
import '../../providers/user_provider.dart';

// Watches: totalEntries, averageScore
class DashboardSummaryRow extends ConsumerWidget {
  const DashboardSummaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalEntriesAsync = ref.watch(analyticsTotalEntriesProvider);
    final avgScoreAsync = ref.watch(analyticsAverageScoreProvider);

    return Row(
      children: [
        Expanded(
          child: DashboardSummaryCard(
            label: "Total Entries",
            value: totalEntriesAsync.when(
              data: (v) => v.toString(),
              loading: () => '—',
              error: (e, _) => '—',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DashboardSummaryCard(
            label: "Avg. Score",
            value: avgScoreAsync.when(
              data: (v) => '${v.toStringAsFixed(1)}%',
              loading: () => '—',
              error: (e, _) => '—',
            ),
          ),
        ),
      ],
    );
  }
}

// Watches: userProfileProvider (already separate)
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider).value;
    if (userProfile == null) return const SizedBox.shrink();

    return DashboardSummaryCard(
      label: "Streak",
      value: "${userProfile.currentStreak} Days",
      subValue: "Longest: ${userProfile.longestStreak}",
    );
  }
}

// Watches: studyTimeToday
class StudyTimeCard extends ConsumerWidget {
  const StudyTimeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studyTimeAsync = ref.watch(analyticsStudyTimeProvider);

    return GlassCard(
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
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          Text(
            studyTimeAsync.when(
              data: (v) => '${(v / 60).round()} min',
              loading: () => '— min',
              error: (e, _) => '— min',
            ),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Watches: proficiencyOverTime, predictedProficiencyOverTime
class ProficiencyChartCard extends ConsumerWidget {
  const ProficiencyChartCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(analyticsProficiencyProvider);
    final predictionAsync = ref.watch(analyticsPredictedProficiencyProvider);

    final history = historyAsync.hasValue ? historyAsync.value : null;
    final prediction = predictionAsync.hasValue ? predictionAsync.value : null;

    if (history == null || prediction == null) {
      return const SizedBox.shrink();
    }

    return ProficiencyLineChart(history: history, prediction: prediction);
  }
}

// Watches: dueCounts
class SrsForecastCard extends ConsumerWidget {
  const SrsForecastCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueCountsAsync = ref.watch(analyticsDueCountsProvider);
    final dueCounts = dueCountsAsync.hasValue ? dueCountsAsync.value : null;
    if (dueCounts == null) return const SizedBox.shrink();

    return SrsForecastWidget(counts: dueCounts);
  }
}

// Watches: goalProgressProvider (already separate)
class GoalProgressSection extends ConsumerWidget {
  const GoalProgressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalProgressAsync = ref.watch(goalProgressProvider);
    if (!goalProgressAsync.hasValue) return const SizedBox.shrink();

    return GoalProgressWidget(progress: goalProgressAsync.value!);
  }
}

// Watches: activityHeatmapProvider (already separate)
class HeatmapSection extends ConsumerWidget {
  const HeatmapSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapAsync = ref.watch(activityHeatmapProvider);
    if (!heatmapAsync.hasValue) return const SizedBox.shrink();

    return SimpleHeatmap(data: heatmapAsync.value!);
  }
}

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalEntriesAsync = ref.watch(analyticsTotalEntriesProvider);

    return GlassScaffold(
      title: 'Analytics',
      subtitle: 'Your fluency timeline',
      showBackButton: true,
      body: totalEntriesAsync.when(
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
        data: (totalEntries) {
          final hasData = totalEntries > 0;

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
                const DashboardSummaryRow(),
                const SizedBox(height: 12),
                const StreakCard(),
                const SizedBox(height: 24),
                const GoalProgressSection(),
                const SizedBox(height: 12),
                const StudyTimeCard(),
                const SizedBox(height: 24),
                const ProficiencyChartCard(),
                const SizedBox(height: 24),
                const SrsForecastCard(),
                const SizedBox(height: 24),
                const HeatmapSection(),
                const SizedBox(height: 40),
              ].animate(interval: 100.ms).fadeIn().slideY(begin: 0.1, end: 0),
            ),
          );
        },
      ),
    );
  }
}
