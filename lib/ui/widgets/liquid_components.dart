// lib/ui/widgets/liquid_components.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/liquid_theme.dart';

// Logo Widget
class AppLogo extends StatelessWidget {
  final bool small;
  final double? width;

  const AppLogo({super.key, this.small = false, this.width});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      small ? 'app_logo_small.svg' : 'app_logo.svg',
      width: width ?? (small ? 40 : 120),
      colorFilter: ColorFilter.mode(
        isDark ? Colors.white : LiquidTheme.primaryAccent,
        BlendMode.srcIn,
      ),
    );
  }
}

// 1. The Animated "Liquid" Background (iOS 26 Style)
class LiquidBackground extends StatelessWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Deep Base color
        Container(
          color: isDark ? const Color(0xFF080A10) : const Color(0xFFF2F4F7),
        ),
        // Animated Liquid Blobs
        Positioned(
          top: -150,
          right: -100,
          child:
              _LiquidBlob(
                    color: LiquidTheme.primaryAccent.withOpacity(
                      isDark ? 0.25 : 0.15,
                    ),
                    size: 500,
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(
                    begin: -30,
                    end: 40,
                    duration: 8.seconds,
                    curve: Curves.easeInOutSine,
                  )
                  .then()
                  .moveY(
                    begin: 40,
                    end: -30,
                    duration: 8.seconds,
                    curve: Curves.easeInOutSine,
                  ),
        ),
        Positioned(
          bottom: -100,
          left: -150,
          child:
              _LiquidBlob(
                    color: const Color(
                      0xFF8B5CF6,
                    ).withOpacity(isDark ? 0.20 : 0.12), // Indigo mix
                    size: 600,
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .moveX(
                    begin: -40,
                    end: 50,
                    duration: 10.seconds,
                    curve: Curves.easeInOutSine,
                  )
                  .then()
                  .moveX(
                    begin: 50,
                    end: -40,
                    duration: 10.seconds,
                    curve: Curves.easeInOutSine,
                  ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          left: MediaQuery.of(context).size.width * 0.1,
          child:
              _LiquidBlob(
                    color: const Color(
                      0xFF06B6D4,
                    ).withOpacity(isDark ? 0.15 : 0.08), // Cyan mix
                    size: 450,
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.1, 1.1),
                    duration: 7.seconds,
                    curve: Curves.easeInOutSine,
                  )
                  .then()
                  .scale(
                    begin: const Offset(1.1, 1.1),
                    end: const Offset(0.8, 0.8),
                    duration: 7.seconds,
                    curve: Curves.easeInOutSine,
                  ),
        ),
        // The content
        child,
      ],
    );
  }
}

class _LiquidBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _LiquidBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
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
    this.borderRadius = 28.0, // iOS cards are highly rounded
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
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.02),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            width: 1.0,
          ),
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 40,
          sigmaY: 40,
        ), // Strong blur for liquid glass
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(
                      0.6,
                    ), // Pronounced rim light in light mode
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.02),
                    ]
                  : [
                      Colors.white.withOpacity(0.7),
                      Colors.white.withOpacity(0.3),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
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
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.08),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
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
              dropdownColor: isDark ? const Color(0xFF1E2128) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
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
