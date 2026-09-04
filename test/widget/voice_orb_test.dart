import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/viewmodels/voice_conversation_state.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/widgets/voice/voice_orb.dart';

/// The orb paints rather than composes, so there is no subtree to assert
/// against. The motion itself is pinned through [orbCoreScale], which is the
/// pure function the painter draws from; the widget tests cover the things only
/// a live element has — whether the clock is running, and what a screen reader
/// is told.
void main() {
  group('motion', () {
    test('listening breathes within its stated amplitude', () {
      // Never larger than the 5% the motion table promises, and it does reach
      // it — a breathe that never opens is just a still orb.
      var seenLow = false;
      var seenHigh = false;

      for (var ms = 0.0; ms < 2200; ms += 25) {
        final scale = orbCoreScale(
          phase: VoicePhase.listening,
          elapsedMs: ms,
          level: 0,
          activity: 1,
        );
        expect(scale, inInclusiveRange(1.0, 1.05));
        if (scale < 1.005) seenLow = true;
        if (scale > 1.045) seenHigh = true;
      }

      expect(seenLow && seenHigh, isTrue);
    });

    test('capturing follows the voice', () {
      double at(double level) => orbCoreScale(
            phase: VoicePhase.capturing,
            elapsedMs: 0,
            level: level,
            activity: 1,
          );

      expect(at(1), greaterThan(at(0.5)));
      expect(at(0.5), greaterThan(at(0)));
    });

    test('capturing still moves when the level never arrives', () {
      // A platform that does not report levels, or a passenger pausing between
      // words. A motionless orb while the microphone is open reads as broken.
      final scales = <double>[
        for (var ms = 0.0; ms < 2200; ms += 50)
          orbCoreScale(
            phase: VoicePhase.capturing,
            elapsedMs: ms,
            level: 0,
            activity: 1,
          ),
      ];

      expect(scales.reduce((a, b) => a > b ? a : b),
          greaterThan(scales.reduce((a, b) => a < b ? a : b) + 0.01));
    });

    test('a loud voice outweighs the blended breathe', () {
      // The breathe is a floor, not something that fights the voice for the
      // radius.
      final loud = orbCoreScale(
        phase: VoicePhase.capturing,
        elapsedMs: 1100,
        level: 1,
        activity: 1,
      );
      final quiet = orbCoreScale(
        phase: VoicePhase.capturing,
        elapsedMs: 1100,
        level: 0,
        activity: 1,
      );

      expect(loud, greaterThan(quiet + 0.15));
    });

    test('the non-scaling forms leave the core alone', () {
      // Orbit, ripple and sweep say their piece with dots, rings and an arc.
      // Swelling as well would blur them back into the same gesture.
      for (final phase in [
        VoicePhase.thinking,
        VoicePhase.preparing,
        VoicePhase.speaking,
        VoicePhase.acknowledging,
        VoicePhase.recovering,
        VoicePhase.idle,
        VoicePhase.permissionDenied,
      ]) {
        expect(
          orbCoreScale(
            phase: phase,
            elapsedMs: 700,
            level: 1,
            activity: 1,
          ),
          1.0,
          reason: '$phase should not scale its core',
        );
      }
    });

    test('at rest the orb is exactly its resting size', () {
      // Not merely close to it: this is what makes leaving a phase ease out
      // rather than pop, and an off-by-a-fraction here is visible.
      for (final phase in VoicePhase.values) {
        expect(
          orbCoreScale(
            phase: phase,
            elapsedMs: 900,
            level: 1,
            activity: 0,
          ),
          1.0,
          reason: '$phase should come fully to rest',
        );
      }
    });

    test('a level outside 0..1 cannot inflate the orb past its amplitude', () {
      expect(
        orbCoreScale(
          phase: VoicePhase.capturing,
          elapsedMs: 0,
          level: 40,
          activity: 1,
        ),
        lessThanOrEqualTo(1.22),
      );
    });
  });

  group('widget', () {
    Future<void> pumpOrb(
      WidgetTester tester, {
      required VoicePhase phase,
      ValueListenable<double>? level,
      VoidCallback? onTap,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VoiceOrb(
                phase: phase,
                level: level,
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a moving phase keeps scheduling frames', (tester) async {
      await pumpOrb(tester, phase: VoicePhase.listening);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('a still phase stops the clock rather than repainting forever',
        (tester) async {
      // permissionDenied is terminal — only the passenger can resolve it, from
      // system settings — so the orb can sit in it indefinitely. It must not
      // keep drawing an unchanging circle at the refresh rate.
      await pumpOrb(tester, phase: VoicePhase.permissionDenied);
      await tester.pumpAndSettle();

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('leaving a moving phase settles instead of running on',
        (tester) async {
      await pumpOrb(tester, phase: VoicePhase.speaking);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await pumpOrb(tester, phase: VoicePhase.idle);
      await tester.pumpAndSettle();

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a null level is safe', (tester) async {
      await pumpOrb(tester, phase: VoicePhase.capturing);
      await tester.pump(const Duration(milliseconds: 32));

      expect(tester.takeException(), isNull);
    });

    testWidgets('each phase is announced to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpOrb(tester, phase: VoicePhase.listening);
      expect(find.bySemanticsLabel('Listening. Tap to stop.'), findsOneWidget);

      await pumpOrb(tester, phase: VoicePhase.speaking);
      await tester.pump();
      expect(
        find.bySemanticsLabel('Speaking. Tap to interrupt.'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('a tap interrupts', (tester) async {
      var taps = 0;
      await pumpOrb(
        tester,
        phase: VoicePhase.speaking,
        onTap: () => taps++,
      );

      await tester.tap(find.byType(VoiceOrb));
      expect(taps, 1);
    });
  });
}
