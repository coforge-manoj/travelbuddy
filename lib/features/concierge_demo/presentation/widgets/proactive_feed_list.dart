import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/features/concierge_demo/presentation/pages/scenario_chat_page.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/widgets/concierge_moments_list.dart';

/// The home-screen proactive feed: the same [ConciergeMomentsList] pill list
/// shown in the main chat's quick actions, so both surfaces present the 12
/// Journey Concierge use cases identically. Tapping one opens its scripted
/// conversation in [ScenarioChatPage].
class ProactiveFeedList extends StatelessWidget {
  const ProactiveFeedList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: [
        ConciergeMomentsList(
          onSelected: (scenario) => Navigator.of(context).push(ScenarioChatPage.route(scenario)),
        ),
      ],
    );
  }
}
