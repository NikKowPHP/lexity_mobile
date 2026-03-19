import 'package:flutter/material.dart';
import '../../../widgets/liquid_components.dart';

class ProfileDataSection extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onExport;
  const ProfileDataSection({required this.onReset, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          _ActionRow(
            label: "Export My Data",
            icon: Icons.download,
            onTap: onExport,
          ),
          const Divider(color: Colors.white10),
          _ActionRow(
            label: "Restart Onboarding",
            icon: Icons.refresh,
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ActionRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.white70),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
