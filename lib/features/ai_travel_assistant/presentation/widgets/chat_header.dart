import 'package:flutter/material.dart';

/// Custom header for the chat screen, styled to match the host app's
/// landing screen branding: back navigation, the TravelBuddy avatar/title,
/// and an overflow menu.
class ChatHeader extends StatelessWidget {
  const ChatHeader({super.key, required this.onBack, this.onMorePressed});

  final VoidCallback onBack;
  final VoidCallback? onMorePressed;

  static const brandBlue = Color(0xFF0883F9);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14171C) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: brandBlue),
              ),
              const _BuddyAvatar(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TravelBuddy',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Your smart travel companion',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              _MoreButton(onPressed: onMorePressed),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuddyAvatar extends StatelessWidget {
  const _BuddyAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/icons/Buddy.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        color: Colors.grey.shade700,
        onPressed: onPressed,
        icon: const Icon(Icons.more_horiz),
      ),
    );
  }
}
