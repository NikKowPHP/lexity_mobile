import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics.dart';
import '../services/analytics_service.dart';
import 'user_provider.dart';

final analyticsDataProvider = FutureProvider.autoDispose<AnalyticsData>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  final activeLang = ref.watch(activeLanguageProvider);
  return service.fetchAnalytics(activeLang);
});

final goalProgressProvider = FutureProvider.autoDispose<GoalProgress>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  return service.fetchGoalProgress();
});

final activityHeatmapProvider = FutureProvider.autoDispose<List<ActivityHeatmapPoint>>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  final activeLang = ref.watch(activeLanguageProvider);
  return service.fetchActivityHeatmap(activeLang);
});

final practiceAnalyticsProvider = FutureProvider.autoDispose<List<PracticeConcept>>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  final activeLang = ref.watch(activeLanguageProvider);
  return service.fetchPracticeAnalytics(activeLang);
});
