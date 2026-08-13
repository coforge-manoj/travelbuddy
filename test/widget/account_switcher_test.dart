import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_travel_assistant/core/services/active_account_store.dart';
import 'package:ai_travel_assistant/core/services/shared_preferences_provider.dart';
import 'package:ai_travel_assistant/features/account/presentation/pages/account_list_page.dart';
import 'package:ai_travel_assistant/features/landing/presentation/pages/landing_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> freshPreferences([
    Map<String, Object> initial = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.of(initial));
    return SharedPreferences.getInstance();
  }

  testWidgets('the home greeting opens the switcher and adopts the picked account',
      (tester) async {
    final preferences = await freshPreferences();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: LandingPage()),
      ),
    );
    await tester.pump();

    // Default account on a fresh install.
    expect(find.text('Hi, Elena'), findsOneWidget);

    await tester.tap(find.text('Hi, Elena'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountListPage), findsOneWidget);
    for (final account in demoAccounts) {
      expect(find.text(account.fullName), findsOneWidget);
    }

    await tester.tap(find.text('Ava Delgado'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountListPage), findsNothing);
    expect(find.text('Hi, Ava'), findsOneWidget);
    // The member number is what every backend call carries, so it is the
    // part that has to stick.
    expect(preferences.getString('active_member_no'), '3XK41RT');
  });

  test('the stored member number is restored on the next launch', () async {
    final preferences =
        await freshPreferences(<String, Object>{'active_member_no': '9BX37KM'});
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(activeAccountProvider).fullName, 'Marcus Bennett');
  });

  test('an unknown stored member number falls back to the first account', () async {
    final preferences =
        await freshPreferences(<String, Object>{'active_member_no': 'GONE123'});
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(activeAccountProvider).memberNo, demoAccounts.first.memberNo);
  });
}
