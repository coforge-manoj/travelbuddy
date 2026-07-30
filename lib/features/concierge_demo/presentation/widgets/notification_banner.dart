import 'package:flutter/material.dart';

/// Sticky strip pinned under [ChatHeader] recapping the push notification
/// the passenger tapped to get here — shown once per session, not as a chat
/// message, since it was already "seen" before the tap.
class NotificationBanner extends StatelessWidget {
  const NotificationBanner({super.key, required this.text});

  final String text;

  static const _brandBlue = Color(0xFF0883F9);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? _brandBlue.withOpacity(0.16) : _brandBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _brandBlue.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_outlined, size: 18, color: _brandBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
