import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GlassScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget body;
  final Widget? floatingActionButton;
  final bool? showBackButton;
  final VoidCallback? onBackPressed;
  final Future<void> Function()? onRefresh;

  const GlassScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.floatingActionButton,
    this.showBackButton,
    this.onBackPressed,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final canPop = showBackButton ?? context.canPop();
    final topPadding = MediaQuery.of(context).padding.top + 20;

    final scrollView = CustomScrollView(
      physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 100 : 24,
              topPadding,
              24,
              20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canPop)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        if (onBackPressed != null) {
                          onBackPressed!();
                        } else if (context.canPop()) {
                          context.pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: body,
        ),
        // Spacer for Bottom Navigation Bar
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      floatingActionButton: floatingActionButton,
      body: onRefresh != null
          ? RefreshIndicator(
              onRefresh: onRefresh!,
              color: const Color(0xFF6C63FF),
              backgroundColor: const Color(0xFF1A1A1A),
              child: scrollView,
            )
          : scrollView,
    );
  }
}
