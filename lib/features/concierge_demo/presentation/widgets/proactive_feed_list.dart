import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/features/concierge_demo/data/scenario_catalog.dart';
import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/pages/scenario_chat_page.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/widgets/proactive_feed_card.dart';

/// The home-screen proactive feed: every [scenarioCatalog] entry, grouped
/// and ordered by [TripStage] (Inspire → Arrival), each opening its scripted
/// conversation in [ScenarioChatPage] on tap.
class ProactiveFeedList extends StatelessWidget {
  const ProactiveFeedList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Journey Concierge',
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
              ProactiveFeedCard(
                scenario: scenario,
                onTap: () => Navigator.of(context).push(ScenarioChatPage.route(scenario)),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ],
    );
  }
}
