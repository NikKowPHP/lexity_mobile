import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/glass_scaffold.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'More',
      subtitle: 'Additional options',
      showBackButton: false,
      body: SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 8),
          _MoreItem(
            icon: LucideIcons.user,
            title: 'Profile',
            subtitle: 'Manage your account settings',
            onTap: () => context.push('/profile'),
          ),
          _MoreItem(
            icon: LucideIcons.barChart2,
            title: 'Progress',
            subtitle: 'View your learning analytics',
            onTap: () => context.push('/progress'),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: "ACCOUNT"),
          _MoreItem(
            icon: LucideIcons.settings,
            title: 'Settings',
            subtitle: 'App preferences and configuration',
            onTap: () => context.push('/profile'),
          ),
          _MoreItem(
            icon: LucideIcons.bell,
            title: 'Notifications',
            subtitle: 'Manage notification preferences',
            onTap: () {},
          ),
          _MoreItem(
            icon: LucideIcons.moon,
            title: 'Appearance',
            subtitle: 'Theme and display options',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: "DATA"),
          _MoreItem(
            icon: LucideIcons.database,
            title: 'Vocabulary',
            subtitle: 'Review and manage saved words',
            onTap: () => context.push('/vocabulary'),
          ),
          _MoreItem(
            icon: LucideIcons.history,
            title: 'SRS Items',
            subtitle: 'Spaced repetition review items',
            onTap: () => context.push('/srs-items'),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: "SUPPORT"),
          _MoreItem(
            icon: LucideIcons.helpCircle,
            title: 'Help & FAQ',
            subtitle: 'Get help and answers',
            onTap: () {},
          ),
          _MoreItem(
            icon: LucideIcons.mail,
            title: 'Contact Us',
            subtitle: 'Send feedback or report issues',
            onTap: () {},
          ),
          _MoreItem(
            icon: LucideIcons.info,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () {},
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withOpacity(0.8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: Colors.white.withOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
