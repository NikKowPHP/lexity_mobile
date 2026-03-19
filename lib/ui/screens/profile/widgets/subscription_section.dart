import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/user_provider.dart';
import '../../../../models/user_profile.dart';
import '../../../widgets/liquid_components.dart';

class ProfileSubscriptionSection extends ConsumerWidget {
  final UserProfile profile;
  final Function(String) onManage;
  const ProfileSubscriptionSection({
    required this.profile,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = profile.subscriptionTier != "FREE";
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current Plan: ${profile.subscriptionTier}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (isPro) ...[
            Text(
              "Status: ${profile.subscriptionStatus}",
              style: const TextStyle(color: Colors.white70),
            ),
            if (profile.subscriptionPeriodEnd != null)
              Text(
                "Renews: ${profile.subscriptionPeriodEnd.toString().split(' ')[0]}",
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 16),
            LiquidButton(
              text: "Manage Subscription",
              onTap: () async {
                final url = await ref
                    .read(userProfileProvider.notifier)
                    .getManageSubscriptionUrl();
                if (url != null) onManage(url);
              },
            ),
          ] else ...[
            const Text(
              "Upgrade to Pro for unlimited features.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            LiquidButton(
              text: "Upgrade Now",
              onTap: () {
                /* Nav to pricing */
              },
            ),
          ],
        ],
      ),
    );
  }
}
