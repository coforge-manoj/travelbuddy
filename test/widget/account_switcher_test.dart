import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_travel_assistant/core/services/active_account_store.dart';
import 'package:ai_travel_assistant/core/services/shared_preferences_provider.dart';
import 'package:ai_travel_assistant/features/landing/presentation/pages/landing_page.dart';
import 'package:ai_travel_assistant/features/settings/presentation/pages/more_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> freshPreferences([
    Map<String, Object> initial = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.of(initial));
    return SharedPreferences.getInstance();
  }

  testWidgets('switching member on the More tab updates the home greeting',
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

    // The greeting is no longer the switcher — the More tab is.
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byType(MorePage), findsOneWidget);
    expect(find.text('Signed in as Elena Vargas'), findsOneWidget);
    for (final account in demoAccounts) {
      expect(find.text(account.fullName), findsOneWidget);
    }

    await tester.tap(find.text('Ava Delgado'));
    await tester.pumpAndSettle();

    // Selection is reflected in place — the page does not pop.
    expect(find.byType(MorePage), findsOneWidget);
    expect(find.text('Signed in as Ava Delgado'), findsOneWidget);
    // The member number is what every backend call carries, so it is the
    // part that has to stick.
    expect(preferences.getString('active_member_no'), '3XK41RT');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Hi, Ava'), findsOneWidget);
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
