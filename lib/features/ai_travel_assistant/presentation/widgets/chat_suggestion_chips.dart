import 'package:flutter/material.dart';

/// Tappable suggestion chips shown above the message composer, driven by
/// TravelBuddy `/chat` `suggestions` in the latest assistant response.
class ChatSuggestionChips extends StatelessWidget {
  const ChatSuggestionChips({
    super.key,
    required this.suggestions,
    required this.onSelected,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  static const _brandBlue = Color(0xFF0883F9);

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              suggestions.length == 1 ? 'Suggestion' : 'Suggestions',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < suggestions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelected(suggestions[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: _brandBlue.withOpacity(0.4)),
                          color: _brandBlue.withOpacity(0.06),
                        ),
                        child: Text(
                          suggestions[i],
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: _brandBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
