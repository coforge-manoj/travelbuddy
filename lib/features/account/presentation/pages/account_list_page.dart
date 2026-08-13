import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/core/services/active_account_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/booking_session_store.dart';

const _veloNavy = Color(0xFF082340);
const _brandBlue = Color(0xFF0883F9);

/// The demo account switcher, opened by tapping the greeting on Home.
/// Picking a different passenger swaps the member number every backend call
/// carries, so the next chat starts a clean journey with that account's
/// history, tier, and bookings.
class AccountListPage extends ConsumerWidget {
  const AccountListPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const AccountListPage());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeAccountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Switch account'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'The concierge runs as the selected member. Switching starts a '
            'fresh chat against that account.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          for (final account in demoAccounts) ...[
            _AccountTile(
              account: account,
              selected: account.memberNo == active.memberNo,
              onTap: () => _select(context, ref, account),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    DemoAccount account,
  ) async {
    // The last confirmed booking belongs to the outgoing passenger — drop it
    // so a seat or baggage request under the new account doesn't resolve
    // against someone else's flight.
    ref.read(bookingSessionStoreProvider).confirmedBooking = null;
    await ref.read(activeAccountProvider.notifier).select(account);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _brandBlue : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _veloNavy.withOpacity(0.08),
                child: Text(
                  _initials(account.fullName),
                  style: const TextStyle(
                    color: _veloNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${account.tier} · ${account.memberNo}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _brandBlue,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      account.profile,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle, color: _brandBlue, size: 22),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String fullName) {
    final parts = fullName.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
