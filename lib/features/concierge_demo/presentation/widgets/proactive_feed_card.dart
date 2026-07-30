import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';

/// One entry in the home-screen proactive feed: the push-notification copy
/// for a [ProactiveScenario], plus a small "not in AA app today" tag. Tapping
/// opens the scripted conversation.
class ProactiveFeedCard extends StatelessWidget {
  const ProactiveFeedCard({super.key, required this.scenario, required this.onTap});

  final ProactiveScenario scenario;
  final VoidCallback onTap;

  static const _brandBlue = Color(0xFF0883F9);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scenario.notificationText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _AvailabilityTag(availability: scenario.availability),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 20, color: _brandBlue),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityTag extends StatelessWidget {
  const _AvailabilityTag({required this.availability});

  final ScenarioAvailability availability;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        availability.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
