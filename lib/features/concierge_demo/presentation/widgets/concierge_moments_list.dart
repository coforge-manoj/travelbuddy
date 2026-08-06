import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/features/concierge_demo/data/scenario_catalog.dart';
import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';

const _brandBlue = Color(0xFF0883F9);

/// Every [scenarioCatalog] entry as a tappable pill, grouped by [TripStage]
/// (Inspire → Arrival). Shared by the main chat's quick actions and the
/// home-screen feed so both surfaces present the 12 Journey Concierge use
/// cases identically — what [onSelected] does with a tap is up to the
/// caller (send it as a chat message, or push [ScenarioChatPage]).
class ConciergeMomentsList extends StatelessWidget {
  const ConciergeMomentsList({super.key, required this.onSelected, this.showHeader = true});

  final ValueChanged<ProactiveScenario> onSelected;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Concierge moments',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        for (final stage in TripStage.values) ...[
          if (scenarioCatalog.any((s) => s.stage == stage)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(
                stage.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            for (final scenario in scenarioCatalog.where((s) => s.stage == stage)) ...[
              _ConciergeMomentPill(scenario: scenario, onTap: () => onSelected(scenario)),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ],
    );
  }
}

class _ConciergeMomentPill extends StatelessWidget {
  const _ConciergeMomentPill({required this.scenario, required this.onTap});

  final ProactiveScenario scenario;
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
              const Icon(Icons.auto_awesome_outlined, size: 20, color: _brandBlue),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  scenario.useCaseTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _brandBlue,
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
