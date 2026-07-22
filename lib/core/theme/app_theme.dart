import 'package:flutter/material.dart';

/// Centralized light/dark theme for the AI Travel Assistant surface. Meant
/// to be merged into (or referenced by) the host app's own [ThemeData] so
/// the assistant feels native rather than bolted-on.
class AppTheme {
  const AppTheme._();

  static const seed = Color(0xFF0B5FFF);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF0E1116),
    );
  }
}

/// Semantic colors that don't map cleanly onto [ColorScheme] roles (chat
/// bubble backgrounds, etc.).
class ChatColors {
  const ChatColors._();

  static Color userBubble(BuildContext context) => Theme.of(context).colorScheme.primary;

  static Color assistantBubble(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1B1F27)
        : Colors.white;
  }

  static Color errorBubble(BuildContext context) => Theme.of(context).colorScheme.errorContainer;
}
