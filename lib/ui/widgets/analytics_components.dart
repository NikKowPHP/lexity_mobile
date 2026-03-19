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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white54 : Colors.black54;
    final valueColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if (subValue != null)
              Text(
                subValue!,
                style: const TextStyle(
                  color: LiquidTheme.primaryAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      isStatic: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Review Forecast",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ForecastItem(
                label: "Today",
                value: counts.today,
                isDark: isDark,
              ),
              _ForecastItem(
                label: "Tomorrow",
                value: counts.tomorrow,
                isDark: isDark,
              ),
              _ForecastItem(
                label: "This Week",
                value: counts.week,
                isDark: isDark,
              ),
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
  final bool isDark;

  const _ForecastItem({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 12,
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              Text(
                "Weekly Goal",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${progress.completedActivities} / ${progress.goal}",
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            backgroundColor: isDark ? Colors.white10 : Colors.black12,
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
                isDark: isDark,
              ),
              _ActivityIcon(
                icon: Icons.edit_note,
                count: progress.breakdown.journals,
                label: "Journals",
                isDark: isDark,
              ),
              _ActivityIcon(
                icon: Icons.psychology,
                count: progress.breakdown.sessions,
                label: "Sessions",
                isDark: isDark,
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
  final bool isDark;

  const _ActivityIcon({
    required this.icon,
    required this.count,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 4),
        Text(
          "$count",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Text(
            "Proficiency Over Time",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Text(
            "Activity (Last 14 Days)",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
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

              Color color = isDark ? Colors.white10 : Colors.black12;
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
