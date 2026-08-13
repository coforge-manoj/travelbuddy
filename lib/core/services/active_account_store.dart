import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_travel_assistant/core/services/shared_preferences_provider.dart';

/// One of the demo passengers the app can run as. The backend keys every
/// journey off `x-member-no`, so switching the account here switches the
/// whole history, loyalty tier, and booking context the concierge sees.
class DemoAccount {
  const DemoAccount({
    required this.memberNo,
    required this.fullName,
    required this.tier,
    required this.profile,
  });

  final String memberNo;
  final String fullName;

  /// Loyalty tier as the backend reports it, e.g. "Executive Platinum".
  final String tier;

  /// One-line hint about what this account is good for demoing.
  final String profile;

  /// What the greeting and the concierge call the passenger.
  String get firstName => fullName.split(' ').first;
}

/// The seeded demo accounts. The first is the default on a fresh install.
const demoAccounts = <DemoAccount>[
  DemoAccount(
    memberNo: '5QW08HB',
    fullName: 'Elena Vargas',
    tier: 'Executive Platinum',
    profile: 'History and spend — 105 flights over 5 years',
  ),
  DemoAccount(
    memberNo: '9BX37KM',
    fullName: 'Marcus Bennett',
    tier: 'Platinum Pro',
    profile: 'Family trip, documents, journey stages',
  ),
  DemoAccount(
    memberNo: '7RM92QD',
    fullName: 'Marcus Webb',
    tier: 'Platinum Pro',
    profile: 'Booking flow — 40 flights',
  ),
  DemoAccount(
    memberNo: '3XK41RT',
    fullName: 'Ava Delgado',
    tier: 'Gold',
    profile: 'Light flyer — 10 flights',
  ),
];

const _prefsKey = 'active_member_no';

DemoAccount _accountFor(String? memberNo) {
  return demoAccounts.firstWhere(
    (account) => account.memberNo == memberNo,
    orElse: () => demoAccounts.first,
  );
}

/// Persists which demo account the app is signed in as, so the choice
/// survives app restarts.
class ActiveAccountStore extends StateNotifier<DemoAccount> {
  ActiveAccountStore(this._prefs) : super(_accountFor(_prefs.getString(_prefsKey)));

  final SharedPreferences _prefs;

  Future<void> select(DemoAccount account) async {
    if (account.memberNo == state.memberNo) return;
    state = account;
    await _prefs.setString(_prefsKey, account.memberNo);
  }
}

/// Deliberately not `autoDispose` — the signed-in account outlives every
/// chat session and screen. `chatViewModelProvider` watches it, so switching
/// accounts tears down the current chat and starts a fresh session against
/// the new member number.
final activeAccountProvider = StateNotifierProvider<ActiveAccountStore, DemoAccount>((ref) {
  return ActiveAccountStore(ref.watch(sharedPreferencesProvider));
});
