import 'package:flutter/material.dart';

/// The next scripted parent line, offered as a tappable shortcut — styled
/// after `QuickActionsList`'s pills. Tapping sends it exactly like typing it
/// into the composer would.
class SuggestedReplyChip extends StatelessWidget {
  const SuggestedReplyChip({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  static const _brandBlue = Color(0xFF0883F9);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Suggested reply',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _brandBlue.withOpacity(0.4)),
                  color: _brandBlue.withOpacity(0.06),
                ),
                child: Text(
                  '"$text"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _brandBlue,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
