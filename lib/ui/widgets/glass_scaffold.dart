// lib/ui/widgets/glass_scaffold.dart
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

    // Theme aware colors for iOS look
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.black54;
    final btnBgColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);

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
                          color: btnBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: textColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight:
                        FontWeight.w900, // Heavy weight like iOS headings
                    letterSpacing: -0.8,
                    color: textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 16, color: subtitleColor),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: body,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Fix: Let the LiquidBackground show through!
      resizeToAvoidBottomInset: false,
      floatingActionButton: floatingActionButton,
      body: onRefresh != null
          ? RefreshIndicator(
              onRefresh: onRefresh!,
              color: const Color(0xFF6C63FF),
              backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              child: scrollView,
            )
          : scrollView,
    );
  }
}
