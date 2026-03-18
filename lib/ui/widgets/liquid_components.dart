// lib/ui/widgets/liquid_components.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/liquid_theme.dart';

// Logo Widget
class AppLogo extends StatelessWidget {
  final bool small;
  final double? width;

  const AppLogo({super.key, this.small = false, this.width});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      small ? 'app_logo_small.svg' : 'app_logo.svg',
      width: width ?? (small ? 40 : 120),
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
  }
}

// 1. The Static "Liquid" Background
class LiquidBackground extends StatelessWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F111A) : const Color(0xFFF3F3F3),
        gradient: RadialGradient(
          center: const Alignment(-0.5, -0.5),
          radius: 2.0,
          colors: isDark
              ? [const Color(0xFF2C3248), const Color(0xFF0F111A)]
              : [const Color(0xFFFFFFFF), const Color(0xFFE2E8F0)],
        ),
      ),
      child: child,
    );
  }
}

// 2. The High-Performance Glass Card
class GlassCard extends StatelessWidget {
  final Widget child;
  final double padding;
  final double borderRadius;
  final bool isStatic;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = 20.0,
    this.borderRadius = 24.0,
    this.isStatic = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isStatic) {
      return Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: isDark
              ? const Color(0xFF1E2128).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.9),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.black.withOpacity(0.08),
            width: 1.0,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.04),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.7),
                    Colors.white.withValues(alpha: 0.4),
                  ],
          ),
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
              width: 1.0,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ]
                  : [
                      Colors.white.withOpacity(0.6),
                      Colors.white.withOpacity(0.3),
                    ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// 3. Neumorphic/Glass Input Field
class GlassInput extends StatelessWidget {
  final String hint;
  final bool isPassword;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const GlassInput({
    super.key,
    required this.hint,
    required this.controller,
    this.isPassword = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.1),
                width: 1.0,
              ),
            ),
            child: TextField(
              controller: controller,
              obscureText: isPassword,
              onChanged: onChanged,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.4)
                      : Colors.black.withOpacity(0.4),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 4. Primary Liquid Button
class LiquidButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;

  const LiquidButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          color: LiquidTheme.primaryAccent,
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: LiquidTheme.primaryAccent.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

// 5. Liquid Dropdown Selection
class LiquidDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const LiquidDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool valueExists = items.contains(value);
    final T effectiveValue = valueExists ? value : items.first;

    return GlassCard(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: effectiveValue,
              dropdownColor: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white24,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              items: items.map((T val) {
                return DropdownMenuItem<T>(
                  value: val,
                  child: Text(val.toString()),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
