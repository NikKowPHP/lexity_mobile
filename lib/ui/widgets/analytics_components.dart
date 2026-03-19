import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lexity_mobile/theme/liquid_theme.dart';
import 'package:lexity_mobile/ui/widgets/liquid_components.dart';
import '../../models/analytics.dart';
import 'package:intl/intl.dart';

class DashboardSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;
  final VoidCallback? onTap;

  const DashboardSummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.subValue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subValue != null)
              Text(
                subValue!,
                style: const TextStyle(
                  color: LiquidTheme.primaryAccent,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SrsForecastWidget extends StatelessWidget {
  final DueCounts counts;

  const SrsForecastWidget({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isStatic: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Review Forecast",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ForecastItem(label: "Today", value: counts.today),
              _ForecastItem(label: "Tomorrow", value: counts.tomorrow),
              _ForecastItem(label: "This Week", value: counts.week),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastItem extends StatelessWidget {
  final String label;
  final int value;

  const _ForecastItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}

class GoalProgressWidget extends StatelessWidget {
  final GoalProgress progress;

  const GoalProgressWidget({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = (progress.goal > 0)
        ? (progress.completedActivities / progress.goal).clamp(0.0, 1.0)
        : 0.0;

    return GlassCard(
      isStatic: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Weekly Goal",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${progress.completedActivities} / ${progress.goal}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.white10,
            color: percent >= 1.0
                ? Colors.greenAccent
                : LiquidTheme.primaryAccent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActivityIcon(
                icon: Icons.check_circle_outline,
                count: progress.breakdown.modules,
                label: "Modules",
              ),
              _ActivityIcon(
                icon: Icons.edit_note,
                count: progress.breakdown.journals,
                label: "Journals",
              ),
              _ActivityIcon(
                icon: Icons.psychology,
                count: progress.breakdown.sessions,
                label: "Sessions",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const _ActivityIcon({
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 4),
        Text(
          "$count",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ProficiencyLineChart extends StatelessWidget {
  final List<TimePoint> history;
  final List<TimePoint> prediction;

  const ProficiencyLineChart({
    super.key,
    required this.history,
    required this.prediction,
  });

  @override
  Widget build(BuildContext context) {
    final allPoints = [...history, ...prediction];
    if (allPoints.isEmpty) return const SizedBox();

    // Convert dates to indices for X axis
    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.score);
    }).toList();

    final predictionSpots = prediction.asMap().entries.map((e) {
      return FlSpot((history.length + e.key).toDouble(), e.value.score);
    }).toList();

    // Connect last history point to first prediction
    if (history.isNotEmpty && prediction.isNotEmpty) {
      predictionSpots.insert(
        0,
        FlSpot((history.length - 1).toDouble(), history.last.score),
      );
    }

    return GlassCard(
      isStatic: true,
      padding: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Proficiency Over Time",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.7,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  show: false,
                ), // Simplified for mobile
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: LiquidTheme.primaryAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: LiquidTheme.primaryAccent.withValues(alpha: 0.1),
                    ),
                  ),
                  if (prediction.isNotEmpty)
                    LineChartBarData(
                      spots: predictionSpots,
                      isCurved: true,
                      color: LiquidTheme.secondaryAccent,
                      barWidth: 3,
                      dashArray: [5, 5],
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SimpleHeatmap extends StatelessWidget {
  final List<ActivityHeatmapPoint> data;

  const SimpleHeatmap({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Create a simple visual grid of last 14 days
    final now = DateTime.now();
    final last14Days = List.generate(
      14,
      (i) => now.subtract(Duration(days: 13 - i)),
    );

    return GlassCard(
      isStatic: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Activity (Last 14 Days)",
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: last14Days.map((date) {
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final point = data.firstWhere(
                (p) => p.date == dateStr,
                orElse: () =>
                    ActivityHeatmapPoint(date: dateStr, totalSeconds: 0),
              );
              final minutes = point.totalSeconds / 60;

              Color color = Colors.white10;
              if (minutes > 0) {
                color = LiquidTheme.primaryAccent.withValues(alpha: 0.3);
              }
              if (minutes > 15) {
                color = LiquidTheme.primaryAccent.withValues(alpha: 0.6);
              }
              if (minutes > 30) color = LiquidTheme.primaryAccent;

              return Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
