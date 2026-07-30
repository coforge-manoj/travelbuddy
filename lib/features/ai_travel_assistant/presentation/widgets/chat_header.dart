import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/theme/app_theme.dart';

/// Custom header for the chat screen, styled to match the host app's
/// landing screen branding: back navigation, the TravelBuddy avatar/title,
/// and a talkback toggle.
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.onBack,
    required this.isTalkbackEnabled,
    required this.onTalkbackToggle,
    this.onMorePressed,
  });

  final VoidCallback onBack;
  final bool isTalkbackEnabled;
  final VoidCallback onTalkbackToggle;
  final VoidCallback? onMorePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ChatColors.bar(context),
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
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: AppTheme.brandBlue),
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
              IconButton(
                tooltip: isTalkbackEnabled ? 'Turn talkback off' : 'Turn talkback on',
                onPressed: onTalkbackToggle,
                icon: Icon(
                  isTalkbackEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: isTalkbackEnabled ? AppTheme.brandBlue : Colors.grey.shade500,
                ),
              ),
              if (onMorePressed != null) _MoreButton(onPressed: onMorePressed),
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
