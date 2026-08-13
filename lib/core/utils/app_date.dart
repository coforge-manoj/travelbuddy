import 'package:intl/intl.dart';

/// The app's single source of "now", and the one place a date is formatted
/// for the screen.
///
/// Two problems it solves:
///
/// 1. The language models had no idea what day it was, so "flights to Tokyo
///    tomorrow" reached the backend either dateless or with a guessed year.
///    [promptContext] is prepended to every classification prompt so relative
///    dates resolve against a real calendar day.
/// 2. Cards each carried their own `DateFormat`, so the same trip could read
///    "21 Jul 2026" on one card and "Sun, Jul 21" on the next. [format] is
///    now the only display format in chat.
///
/// [clock] is the seam: set it once at startup to pin a demo to a fixed day,
/// or in a test to make date-dependent output deterministic.
class AppDate {
  AppDate._();

  /// Override to pin the app to a fixed day:
  /// `AppDate.clock = () => DateTime(2026, 4, 9);`
  ///
  /// Reset to [DateTime.new]'s default in test teardown — it is global state.
  static DateTime Function() clock = DateTime.now;

  static DateTime get now => clock();

  /// Today at midnight. Compare against this rather than [now] when only the
  /// calendar day matters, and add [Duration]s to it to reach other days.
  static DateTime get today {
    final n = now;
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime get tomorrow => today.add(const Duration(days: 1));

  /// The one display format for dates in chat: `August-13-2026`.
  static final DateFormat displayFormat = DateFormat('MMMM-dd-yyyy');

  /// What the backend and the search prompts speak: `2026-08-13`.
  static final DateFormat isoFormat = DateFormat('yyyy-MM-dd');

  static final DateFormat _timeFormat = DateFormat.Hm();
  static final DateFormat _weekdayFormat = DateFormat('EEEE');

  /// For the ear, not the eye: the display form's hyphens come out of a
  /// speech engine as "August dash thirteen dash two thousand".
  static final DateFormat _spokenFormat = DateFormat('MMMM d, y');

  static String format(DateTime date) => displayFormat.format(date);

  /// `August-13-2026 · 09:40` — for cards that name a departure, where the
  /// time is as load-bearing as the day.
  static String formatWithTime(DateTime date) =>
      '${displayFormat.format(date)} · ${_timeFormat.format(date)}';

  /// Formats a date the backend sent as text. Anything unparseable is
  /// returned exactly as it arrived — a card should never blank out or
  /// mangle a value it does not recognise.
  static String? formatRaw(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;
    final parsed = DateTime.tryParse(trimmed);
    return parsed == null ? raw : format(parsed);
  }

  /// A backend date string shaped for narration — "August 13, 2026".
  /// Unparseable input is returned unchanged, as in [formatRaw].
  static String? formatSpokenRaw(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;
    final parsed = DateTime.tryParse(trimmed);
    return parsed == null ? raw : _spokenFormat.format(parsed);
  }

  /// Today as `2026-08-13`.
  static String get todayIso => isoFormat.format(today);

  /// Tomorrow as `2026-08-14`.
  static String get tomorrowIso => isoFormat.format(tomorrow);

  /// Today as `August-13-2026`.
  static String get todayDisplay => format(today);

  /// Date grounding for the LLM prompts. Built per call, not cached, so a
  /// session running across midnight — or a demo that moves [clock] — sees
  /// the change on the next turn.
  ///
  /// The resolution rules travel with the date rather than living in the
  /// individual prompt files: every prompt that gets the date needs the same
  /// rules, and one of them drifting is how "tomorrow" ends up a year out.
  static String get promptContext {
    final t = today;
    final iso = isoFormat.format(t);
    final weekday = _weekdayFormat.format(t);

    return '''
CURRENT DATE CONTEXT

Today's date is $iso ($weekday).
Tomorrow's date is ${isoFormat.format(t.add(const Duration(days: 1)))}.

RELATIVE DATE RULES

Resolve every relative date against today's date above, and emit the result
as yyyy-MM-dd.

- "today", "tonight", "later today" -> $iso
- "tomorrow" -> ${isoFormat.format(t.add(const Duration(days: 1)))}
- "day after tomorrow" -> ${isoFormat.format(t.add(const Duration(days: 2)))}
- "next week", "in 3 days", "this weekend", "next Friday", "next month" ->
  compute the actual calendar date from today's date.
- A day or month given without a year ("on 5 September", "in April") means
  the NEXT occurrence on or after today's date.

Never output a travel date earlier than $iso.
Never ask the user for a date you can compute from these rules.''';
  }
}
