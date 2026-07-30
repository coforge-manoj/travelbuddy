import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/core/theme/app_theme.dart';

/// One tappable shortcut in the [QuickActionsList] — an icon/label shown to
/// the passenger, and the utterance sent through the normal chat pipeline
/// when tapped.
class QuickAction {
  const QuickAction({required this.icon, required this.label, required this.prompt});

  final IconData icon;
  final String label;
  final String prompt;
}

const quickActions = <QuickAction>[
  QuickAction(
    icon: Icons.airplane_ticket_outlined,
    label: 'Book a Flight',
    prompt: 'I want to book a flight',
  ),
  QuickAction(icon: Icons.flight_outlined, label: 'Flight Status', prompt: 'Is my flight on time?'),
  QuickAction(
    icon: Icons.event_seat_outlined,
    label: 'Seat Selection',
    prompt: "I'd like to select my seat",
  ),
  QuickAction(
    icon: Icons.luggage_outlined,
    label: 'Add Baggage',
    prompt: 'I need to add extra baggage',
  ),
  QuickAction(
    icon: Icons.confirmation_number_outlined,
    label: 'Check-in Counter & Terminal',
    prompt: 'Which check-in counter and terminal do I need?',
  ),
  QuickAction(
    icon: Icons.work_outline,
    label: 'Baggage Allowance',
    prompt: "What's my baggage allowance?",
  ),
  QuickAction(
    icon: Icons.access_time_outlined,
    label: 'Boarding Time',
    prompt: 'What time does my flight begin boarding?',
  ),
  QuickAction(
    icon: Icons.alt_route_outlined,
    label: 'Airport Navigation',
    prompt: 'How do I get to my gate?',
  ),
  QuickAction(
    icon: Icons.description_outlined,
    label: 'Travel Documents',
    prompt: 'What travel documents do I need?',
  ),
];

/// The stack of quick-action pills shown alongside the welcome message,
/// styled to match the landing screen's card/pill language.
class QuickActionsList extends StatelessWidget {
  const QuickActionsList({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          for (final action in quickActions) ...[
            _QuickActionPill(action: action, onTap: () => onSelected(action.prompt)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _QuickActionPill extends StatelessWidget {
  const _QuickActionPill({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(action.icon, size: 20, color: AppTheme.brandBlue),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  action.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.brandBlue,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
