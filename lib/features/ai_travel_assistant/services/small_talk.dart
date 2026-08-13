import 'dart:math';

import 'package:ai_travel_assistant/core/utils/app_date.dart';

/// The conversational openers and closers a travel assistant gets asked, which
/// are not requests for anything.
///
/// These arrive as `IntentType.unknown` — the classifier is looking for a
/// travel action and a greeting contains none — and without special handling
/// they land on the capability offer, which answers "hello" with "I'm not sure
/// I can help with that one". A passenger who says hello and is told the
/// assistant cannot help has learned something false about it in the first
/// sentence of the conversation.
enum SmallTalk {
  greeting,

  /// "How are you" — answered rather than deflected, then handed back.
  wellbeing,

  thanks,

  farewell,

  /// "What can you do" — the one kind of small talk that genuinely wants the
  /// capability list, just without the apology in front of it.
  capabilities,
}

/// What kind of small talk [utterance] is, or `null` when it is a real request.
///
/// Matched against the **whole** utterance, not searched within it. "Hi, can
/// you book me a flight to London" opens with a greeting but is a booking, and
/// answering it with "Hello Elena, what can I do for you?" would drop the
/// request on the floor — the worse failure of the two, because the passenger
/// has to say it all again.
SmallTalk? classifySmallTalk(String utterance) {
  final cleaned = utterance
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z'\s]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return null;

  for (final entry in _patterns.entries) {
    if (entry.value.hasMatch(cleaned)) return entry.key;
  }
  return null;
}

/// Anchored on both ends, so only an utterance that is *nothing but* small talk
/// matches. The optional tails ("there", "again", "travel buddy") are the
/// words people habitually attach to a greeting without changing what it is.
final _patterns = <SmallTalk, RegExp>{
  SmallTalk.greeting: RegExp(
    r'^(hello|hi+|hey+|yo|greetings|good (morning|afternoon|evening|day))'
    r'( there| again| travel ?buddy| buddy)*$',
  ),
  SmallTalk.wellbeing: RegExp(
    r"^(how are you|how're you|how are you doing|how you doing|"
    r"how's it going|hows it going|how do you do|are you (ok|okay|well))"
    r'( today| doing)?$',
  ),
  SmallTalk.thanks: RegExp(
    r'^(thanks|thank you|thankyou|thanks a lot|thank you so much|'
    r'thanks so much|cheers|appreciate it|much appreciated)'
    r'( mate| buddy)?$',
  ),
  SmallTalk.farewell: RegExp(
    r"^(bye|bye bye|goodbye|good bye|see you|see ya|see you later|"
    r"good night|goodnight|that's all|thats all|that's it|thats it|"
    r"nothing else|no thanks|i'm done|im done|we're done)$",
  ),
  SmallTalk.capabilities: RegExp(
    r'^(what can you do|what do you do|what can you help( me)? with|'
    r'what else can you do|who are you|what are you|'
    r'what can i ask( you)?|help|help me)$',
  ),
};

/// Wording for a small-talk reply.
///
/// Pools with no back-to-back repeat, for the same reason
/// `AcknowledgementComposer` has them: a demo that greets you with the
/// identical sentence every run sounds like a recording, and the greeting is
/// the first thing anyone hears.
class SmallTalkComposer {
  SmallTalkComposer({Random? random}) : _random = random ?? Random();

  final Random _random;
  final Map<List<String>, int> _lastPicks = {};

  /// The reply to [kind].
  ///
  /// [travelerFirstName] is used where a name lands naturally — a greeting —
  /// and left out where repeating it would sound like a script ("Anytime,
  /// Elena. Happy to help, Elena.").
  ///
  /// [offers] are the assistant-voiced capabilities, and are folded in only
  /// where the passenger is being invited to choose: on a greeting they would
  /// pre-empt someone who already knows what they want, so the greeting simply
  /// asks. Nothing here promises a lookup — no request has been made.
  String compose(
    SmallTalk kind, {
    required String travelerFirstName,
    required List<String> offers,
  }) {
    final name = travelerFirstName.trim();
    final withName = name.isEmpty ? '' : ' $name';

    return switch (kind) {
      SmallTalk.greeting =>
        '${_pick(_greetingStarters)}$withName. ${_pick(_openInvites)}',
      SmallTalk.wellbeing => '${_pick(_wellbeing)} ${_pick(_openInvites)}',
      SmallTalk.thanks => _pick(_thanks),
      SmallTalk.farewell => _pick(_farewells),
      SmallTalk.capabilities => _capabilityLine(offers),
    };
  }

  /// The capability list without an apology in front of it — this passenger
  /// asked what the assistant does, which is not a failure to understand them.
  String _capabilityLine(List<String> offers) {
    final spoken = offers.take(3).toList();
    if (spoken.isEmpty) return _pick(_openInvites);
    return switch (spoken.length) {
      1 => 'I can ${spoken.first}. ${_pick(_openInvites)}',
      2 => 'I can ${spoken[0]}, or ${spoken[1]}. ${_pick(_openInvites)}',
      _ => 'I can ${spoken[0]}, ${spoken[1]}, or ${spoken[2]} — among other '
          'things. ${_pick(_openInvites)}',
    };
  }

  /// Built once so [_pick] can remember its last choice against a stable
  /// list. The day-part greeting is whatever the clock said when this
  /// composer was first asked — a session that starts at 11:59 stays on
  /// "Good morning" rather than flipping at noon mid-conversation.
  late final List<String> _greetingStarters = [
    'Hello',
    'Hi',
    'Hey',
    'Good to see you',
    'Good day',
    _daypartGreeting(),
  ];

  static String _daypartGreeting() {
    final hour = AppDate.now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const _openInvites = <String>[
    'What can I help you with?',
    'What can I do for you?',
    'How can I help?',
    'What are we sorting out today?',
    'What would you like to do?',
  ];

  static const _wellbeing = <String>[
    "I'm doing well, thanks for asking.",
    'All good here, thank you.',
    "I'm well, thanks.",
  ];

  static const _thanks = <String>[
    'Anytime.',
    'Happy to help.',
    'Of course — anything else?',
    'My pleasure.',
  ];

  static const _farewells = <String>[
    'Safe travels.',
    'Take care.',
    'Bye for now — safe trip.',
    'Anytime. Safe travels.',
  ];

  String _pick(List<String> pool) {
    if (pool.length == 1) return pool.first;
    final last = _lastPicks[pool];
    var index = _random.nextInt(pool.length);
    if (index == last) index = (index + 1) % pool.length;
    _lastPicks[pool] = index;
    return pool[index];
  }
}
