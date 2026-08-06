import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/core/services/concierge_visibility_store.dart';
import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/core/services/reminder_delay_store.dart';
import 'package:ai_travel_assistant/core/services/voice_output_setting_store.dart';

/// The push-notification copy for the one scripted scenario that otherwise
/// has none — `inspire-discovery` is meant to start from the passenger
/// simply opening the chat, but this lets the More tab kick it off with a
/// notification instead, for demoing that path too.
const _inspireJourneyScenarioId = 'inspire-discovery';
const _inspireJourneyNotificationBody = 'Are you looking to plan a family trip to Tokyo?';

/// The "More" tab: Journey Concierge settings — how long the post-use-case
/// reminder notification waits before firing, whether the home screen shows
/// the Concierge moments feed, whether chat replies are read aloud, and a
/// way to manually fire the Inspire-journey opening notification.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  static const _brandBlue = Color(0xFF0883F9);

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const MorePage());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSeconds = ref.watch(reminderDelayStoreProvider);
    final conciergeVisible = ref.watch(conciergeVisibilityStoreProvider);
    final voiceOutputEnabled = ref.watch(voiceOutputEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          const _SectionHeader(
            title: 'Concierge moments on Home',
            subtitle: 'Show the Concierge moments pill list on the home screen feed.',
          ),
          _SettingSwitchTile(
            label: conciergeVisible ? 'Shown on Home' : 'Hidden from Home',
            value: conciergeVisible,
            onChanged: (value) =>
                ref.read(conciergeVisibilityStoreProvider.notifier).setVisible(value),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Text-to-speech in chat',
            subtitle: 'Read concierge replies aloud, starting from the next chat session.',
          ),
          _SettingSwitchTile(
            label: voiceOutputEnabled ? 'On' : 'Off',
            value: voiceOutputEnabled,
            onChanged: (value) => ref.read(voiceOutputEnabledProvider.notifier).setEnabled(value),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Concierge reminder delay',
            subtitle: 'How long after finishing a Concierge moment before the follow-up '
                'notification arrives.',
          ),
          for (final seconds in reminderDelayOptionsSeconds) ...[
            _DelayOptionTile(
              seconds: seconds,
              selected: seconds == selectedSeconds,
              onTap: () => ref.read(reminderDelayStoreProvider.notifier).setDelaySeconds(seconds),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Start the Inspire journey',
            subtitle: 'Sends the opening notification for the natural-language destination '
                'discovery moment, the same way the other 11 use cases do.',
          ),
          _StartInspireJourneyButton(delaySeconds: selectedSeconds),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  const _SettingSwitchTile({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: MorePage._brandBlue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DelayOptionTile extends StatelessWidget {
  const _DelayOptionTile({required this.seconds, required this.selected, required this.onTap});

  final int seconds;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? MorePage._brandBlue : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$seconds seconds',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: selected ? MorePage._brandBlue : Colors.black87,
                      ),
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: MorePage._brandBlue, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartInspireJourneyButton extends ConsumerWidget {
  const _StartInspireJourneyButton({required this.delaySeconds});

  final int delaySeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(localNotificationServiceProvider).showAfterDelay(
                payload: _inspireJourneyScenarioId,
                title: 'Journey Concierge',
                body: _inspireJourneyNotificationBody,
                delay: Duration(seconds: delaySeconds),
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Notification arriving in $delaySeconds seconds…')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MorePage._brandBlue.withOpacity(0.4)),
            color: MorePage._brandBlue.withOpacity(0.06),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: MorePage._brandBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Send Inspire journey notification',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: MorePage._brandBlue,
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
