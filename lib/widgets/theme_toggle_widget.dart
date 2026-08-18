import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ember/core/theme/theme_provider.dart';

class CuteThemeToggleWidget extends StatelessWidget {
  const CuteThemeToggleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return GestureDetector(
      onTap: () {
        context.read<ThemeProvider>().toggleTheme();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        width: 64,
        height: 34,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF1E1B4B), Color(0xFF311B92)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.indigo.withValues(alpha: 0.4)
                  : Colors.blue.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Elements (Stars or Sunbeams)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: isDark ? 8 : -20,
              top: 6,
              child: Opacity(
                opacity: isDark ? 1.0 : 0.0,
                child: const Row(
                  children: [
                    Icon(Icons.star, size: 8, color: Color(0xFFFDE047)),
                    SizedBox(width: 4),
                    Icon(Icons.star, size: 6, color: Colors.white70),
                  ],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              right: isDark ? -20 : 8,
              top: 6,
              child: Opacity(
                opacity: isDark ? 0.0 : 1.0,
                child: const Row(
                  children: [
                    Icon(Icons.cloud, size: 10, color: Colors.white70),
                  ],
                ),
              ),
            ),

            // Sliding Sun/Moon Switch Thumb
            AnimatedAlign(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFFFDE047) : const Color(0xFFF59E0B),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0xFFFDE047).withValues(alpha: 0.6)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
