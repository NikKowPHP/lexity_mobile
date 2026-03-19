import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/user_profile.dart';
import '../../../../providers/user_provider.dart';
import '../../../widgets/liquid_components.dart';

class GoalsForm extends ConsumerStatefulWidget {
  final UserProfile profile;
  const GoalsForm({required this.profile});

  @override
  ConsumerState<GoalsForm> createState() => GoalsFormState();
}

class GoalsFormState extends ConsumerState<GoalsForm> {
  late TextEditingController _dailyGoalController;
  late TextEditingController _maxNewController;
  late TextEditingController _maxReviewController;
  int _weeklyActivities = 3;

  @override
  void initState() {
    super.initState();
    final g = widget.profile.goals;
    _weeklyActivities = g?.weeklyActivities ?? 3;
    _dailyGoalController = TextEditingController(
      text: (g?.dailyStudyGoalInMinutes ?? 15).toString(),
    );
    _maxNewController = TextEditingController(
      text: (g?.maxNewPerDay ?? 20).toString(),
    );
    _maxReviewController = TextEditingController(
      text: (g?.maxReviewsPerDay ?? 50).toString(),
    );
  }

  void _saveGoals() {
    final newGoals = UserGoals(
      weeklyActivities: _weeklyActivities,
      dailyStudyGoalInMinutes: int.tryParse(_dailyGoalController.text) ?? 15,
      maxNewPerDay: int.tryParse(_maxNewController.text) ?? 20,
      maxReviewsPerDay: int.tryParse(_maxReviewController.text) ?? 50,
    );
    ref.read(userProfileProvider.notifier).updateGoals(newGoals);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Goals saved!")));
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiquidDropdown<int>(
            label: "Weekly Activities Goal",
            value: _weeklyActivities,
            items: const [3, 5, 7, 10],
            onChanged: (val) => setState(() => _weeklyActivities = val!),
          ),
          const SizedBox(height: 16),
          GlassInput(
            controller: _dailyGoalController,
            hint: "Daily Study Goal (mins)",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GlassInput(
                  controller: _maxNewController,
                  hint: "Max New Cards",
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassInput(
                  controller: _maxReviewController,
                  hint: "Max Reviews",
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LiquidButton(text: "Save Goals", onTap: _saveGoals),
        ],
      ),
    );
  }
}
