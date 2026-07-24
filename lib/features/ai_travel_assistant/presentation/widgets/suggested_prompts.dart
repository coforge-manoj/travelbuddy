import 'package:flutter/material.dart';

const _promptIcons = <String, IconData>{
  'Flight Status': Icons.flight,
  'Seat Selection': Icons.flight_class,
  'Add Baggage': Icons.luggage,
  'Check-in Counter & Terminal': Icons.airplane_ticket,
  'Baggage Allowance': Icons.business_center,
  'Boarding Time': Icons.alarm,
  'Airport Navigation': Icons.route,
  'Travel Documents': Icons.article,
};

/// A stack of full-width, pill-shaped prompt suggestions shown after the
/// welcome message so a passenger can start the conversation with a tap.
class SuggestedPrompts extends StatelessWidget {
  const SuggestedPrompts({super.key, required this.prompts, required this.onSelected});

  final List<String> prompts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (prompts.isEmpty) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        children: [
          for (final prompt in prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => onSelected(prompt),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _promptIcons[prompt] ?? Icons.chat_bubble_outline,
                          size: 20,
                          color: accent,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            prompt,
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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
