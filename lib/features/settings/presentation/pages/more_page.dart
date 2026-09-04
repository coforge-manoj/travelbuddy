import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/core/services/active_account_store.dart';
import 'package:ai_travel_assistant/core/services/concierge_visibility_store.dart';
import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/core/services/reminder_delay_store.dart';
import 'package:ai_travel_assistant/core/services/tts_engine_setting_store.dart';
import 'package:ai_travel_assistant/core/services/voice_output_setting_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/services/concierge_moments_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';

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
    final activeAccount = ref.watch(activeAccountProvider);
    final conciergeVisible = ref.watch(conciergeVisibilityStoreProvider);
    final voiceOutputEnabled = ref.watch(voiceOutputEnabledProvider);
    final ttsEngine = ref.watch(ttsEngineProvider);
    final speechSummaryEnabled = ref.watch(speechSummaryEnabledProvider);

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
          _SectionHeader(
            title: 'Signed in as ${activeAccount.fullName}',
            subtitle: 'The concierge runs as this member — every call carries their '
                'member number. Switching starts a fresh chat against that account.',
          ),
          for (final account in demoAccounts) ...[
            _AccountOptionTile(
              account: account,
              selected: account.memberNo == activeAccount.memberNo,
              onTap: () => _selectAccount(ref, account),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
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
            subtitle: 'Read chat replies aloud, starting from the next chat '
                'session. Voice mode always speaks, and stops when you leave it.',
          ),
          _SettingSwitchTile(
            label: voiceOutputEnabled ? 'On' : 'Off',
            value: voiceOutputEnabled,
            onChanged: (value) => ref.read(voiceOutputEnabledProvider.notifier).setEnabled(value),
          ),
          if (voiceOutputEnabled) ...[
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Voice engine',
              subtitle: 'Which engine reads replies aloud.',
            ),
            for (final engine in TtsEngine.values) ...[
              _TtsEngineOptionTile(
                engine: engine,
                selected: engine == ttsEngine,
                onTap: () => ref.read(ttsEngineProvider.notifier).setEngine(engine),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            const _SectionHeader(
              title: 'Summarize before speaking',
              subtitle: 'Condense replies into a short spoken line instead of '
                  'reading the whole message out.',
            ),
            _SettingSwitchTile(
              label: speechSummaryEnabled ? 'Summarize for audio' : 'Read verbatim',
              value: speechSummaryEnabled,
              onChanged: (value) =>
                  ref.read(speechSummaryEnabledProvider.notifier).setEnabled(value),
            ),
          ],
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
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Send the award-seat alert',
            subtitle: 'Fetches the live push copy for the Tokyo award alert and '
                'delivers it as a notification. Tapping it opens the chat on '
                'that message — the opening beat of the family journey.',
          ),
          _SendAwardAlertButton(
            delaySeconds: selectedSeconds,
            memberNo: activeAccount.memberNo,
          ),
        ],
      ),
    );
  }

  /// Switching member also drops the last confirmed booking: it belongs to
  /// the outgoing passenger, and a seat or baggage request under the new
  /// account must not resolve against someone else's flight. The chat itself
  /// resets on its own — `chatViewModelProvider` watches
  /// [activeAccountProvider].
  void _selectAccount(WidgetRef ref, DemoAccount account) {
    ref.read(bookingSessionStoreProvider).confirmedBooking = null;
    ref.read(activeAccountProvider.notifier).select(account);
  }
}

/// Member picker row — shows the tier and member number, since the member
/// number is what every backend call actually carries.
class _AccountOptionTile extends StatelessWidget {
  const _AccountOptionTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final DemoAccount account;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.fullName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected ? MorePage._brandBlue : Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${account.tier} · ${account.memberNo}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.profile,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 12),
                const Icon(Icons.check_circle, color: MorePage._brandBlue, size: 20),
              ],
            ],
          ),
        ),
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

/// Engine picker row — shows the trade-off inline, since "needs a connection"
/// is the thing a passenger would otherwise only discover by hearing nothing.
class _TtsEngineOptionTile extends StatelessWidget {
  const _TtsEngineOptionTile({
    required this.engine,
    required this.selected,
    required this.onTap,
  });

  final TtsEngine engine;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      engine.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected ? MorePage._brandBlue : Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      engine.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 12),
                const Icon(Icons.check_circle, color: MorePage._brandBlue, size: 20),
              ],
            ],
          ),
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

/// Arms the opening moment of the Bennett journey. Unlike
/// [_StartInspireJourneyButton] — which sends hardcoded copy for a scripted
/// scenario — this fetches the real push string from the backend and hands it
/// to the chat as the concierge's opening line, so the demo never puts words
/// in the concierge's mouth that the backend did not write.
class _SendAwardAlertButton extends ConsumerWidget {
  const _SendAwardAlertButton({
    required this.delaySeconds,
    required this.memberNo,
  });

  final int delaySeconds;
  final String memberNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ActionTile(
      icon: Icons.campaign_outlined,
      label: 'Send award-seat alert',
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final service = ref.read(conciergeMomentsServiceProvider(memberNo));

        final copy = await service.pushCopyFor(
          ConciergeMomentsService.awardAlertUseCase,
        );
        if (copy == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                "Couldn't reach the backend for the alert copy — check /health.",
              ),
            ),
          );
          return;
        }

        ref.read(localNotificationServiceProvider).showAfterDelay(
              payload:
                  '${LocalNotificationService.liveMomentPayloadPrefix}$copy',
              title: 'Journey Concierge',
              body: copy,
              delay: Duration(seconds: delaySeconds),
            );
        // Safe to record here, unlike the document interrupt: this copy is
        // fetched by seq, which ignores delivery state, so the button stays
        // re-armable for a second rehearsal.
        unawaited(
          service.markDelivered(ConciergeMomentsService.awardAlertUseCase),
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text('Award alert arriving in $delaySeconds seconds…'),
          ),
        );
      },
    );
  }
}

/// The shared chrome for the two notification buttons.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
            border: Border.all(color: MorePage._brandBlue.withOpacity(0.4)),
            color: MorePage._brandBlue.withOpacity(0.06),
          ),
          child: Row(
            children: [
              Icon(icon, color: MorePage._brandBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
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
