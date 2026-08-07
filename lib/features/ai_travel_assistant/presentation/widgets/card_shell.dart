import 'package:flutter/material.dart';

/// The chrome every chat card shares: left-aligned, capped at the same width
/// as a chat bubble, with an icon + title header and an optional trailing
/// widget (usually the price). Keeps the journey's cards visually one
/// family instead of each re-deriving padding and radius.
class CardShell extends StatelessWidget {
  const CardShell({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
    this.accent,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  /// Colours the icon and title — used to mark a card as a confirmation
  /// (green), a warning, or a plain informational card (theme primary).
  final Color? accent;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = accent ?? scheme.primary;
    final onSurface = foreground ?? scheme.onSurface;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        decoration: BoxDecoration(
          color: background ?? scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent?.withOpacity(0.35) ?? scheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A label on the left, a value on the right — the layout every price
/// breakdown, payment split and pass detail on these cards uses.
class CardRow extends StatelessWidget {
  const CardRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
    this.muted = false,
    this.valueColor,
  });

  final String label;
  final String value;

  /// Totals — heavier weight on both sides.
  final bool emphasis;

  /// Secondary detail, dimmed.
  final bool muted;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = emphasis ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall;
    final style = base?.copyWith(
      fontWeight: emphasis ? FontWeight.w700 : FontWeight.w400,
      color: muted ? scheme.outline : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(
            value,
            style: style?.copyWith(color: valueColor ?? style.color),
          ),
        ],
      ),
    );
  }
}

/// Full-width rule used to separate a card's sections.
class CardDivider extends StatelessWidget {
  const CardDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

/// Small pill used for cabin names, seat types and status labels.
class CardBadge extends StatelessWidget {
  const CardBadge({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
