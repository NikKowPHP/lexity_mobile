// lib/ui/widgets/liquid_components.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/liquid_theme.dart';

// 1. The Moving "Liquid" Background
class LiquidBackground extends StatelessWidget {
  final Widget child;
  const LiquidBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep background
        Container(color: LiquidTheme.background),

        // Floating Orb 1 (Indigo)
        Positioned(
              top: -100,
              left: -100,
              child: _buildOrb(LiquidTheme.primaryAccent),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .move(
              duration: 4.seconds,
              begin: const Offset(0, 0),
              end: const Offset(50, 100),
            )
            .scale(
              duration: 4.seconds,
              begin: const Offset(1, 1),
              end: const Offset(1.5, 1.5),
            ),

        // Floating Orb 2 (Pink)
        Positioned(
              bottom: -50,
              right: -50,
              child: _buildOrb(LiquidTheme.secondaryAccent),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .move(
              duration: 5.seconds,
              begin: const Offset(0, 0),
              end: const Offset(-60, -80),
            )
            .scale(
              duration: 5.seconds,
              begin: const Offset(1.2, 1.2),
              end: const Offset(0.8, 0.8),
            ),

        // Content on top
        child,
      ],
    );
  }

  Widget _buildOrb(Color color) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 100,
            spreadRadius: 50,
          ),
        ],
      ),
    );
  }
}

// 2. The High-Performance Glass Card
class GlassCard extends StatelessWidget {
  final Widget child;
  final double padding;

  const GlassCard({super.key, required this.child, this.padding = 24.0});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05), // Ultra transparent
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.02),
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

  const GlassInput({
    super.key,
    required this.hint,
    required this.controller,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [LiquidTheme.primaryAccent, LiquidTheme.secondaryAccent],
          ),
          boxShadow: [
            BoxShadow(
              color: LiquidTheme.primaryAccent.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
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
                  ),
                ),
        ),
      ),
    ).animate(target: isLoading ? 0 : 1).shimmer(duration: 2.seconds);
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
    // NEW: Internal safety check to prevent crash if parent passes invalid value
    final bool valueExists = items.contains(value);
    final T effectiveValue = valueExists ? value : items.first;

    return GlassCard(
      padding: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: effectiveValue,
              dropdownColor: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: LiquidTheme.primaryAccent,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              items: items.map((T val) {
                return DropdownMenuItem<T>(
                  value: val,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(val.toString()),
                  ),
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
