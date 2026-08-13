import 'dart:math';

import 'package:meta/meta.dart';

/// Composes the line the assistant says *while* a turn is being answered.
///
/// A request used to be met with silence: the microphone closed, the orb
/// pulsed, and nothing was said until the whole answer came back several
/// seconds later. A person asked to look something up says "sure, let me check
/// that" first, and this builds that line — an opener, what it understood the
/// request to be, and what it is about to go and do.
///
/// **Worded here rather than by the model, deliberately.** Every other spoken
/// line in this app is phrased by the summarizer, but this one cannot be: the
/// LLM round trip is 1.9–3.3s, which is the very gap this line exists to fill.
/// An acknowledgement that arrives after the answer is worse than no
/// acknowledgement at all. The variety that model wording normally provides is
/// therefore built in instead — every part is drawn from a pool that never
/// repeats its previous pick, and the middle clause is the passenger's own
/// words read back, so two turns are near-impossible to hear as the same line.
///
/// **The reflection is conservative on purpose.** It is only attempted when the
/// request matches one of a few shapes that can be restated without mangling;
/// anything else gets an opener and a hold phrase, which are always true and
/// always grammatical. Hearing "you want me to my flight cancel" even once
/// would undo the point of speaking at all.
class AcknowledgementComposer {
  AcknowledgementComposer({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// The last index handed out per pool, so no pool repeats itself back to
  /// back. Keyed by the pool itself — the pools are `const`, so identity is
  /// stable and this needs no enum to tie the two together.
  final Map<List<String>, int> _lastPicks = {};

  /// Requests longer than this are acknowledged without being read back.
  ///
  /// Restating a long request costs more time than the answer would, and the
  /// longer the sentence the likelier the pronoun flip trips over a clause it
  /// was never designed for.
  static const int maxReflectedWords = 14;

  static const _openers = <String>[
    'Sure',
    'Alright',
    'Okay',
    'Got it',
    'Right',
    'Of course',
  ];

  /// Carriers for a request that can be restated as something to do.
  static const _requestCarriers = <String>[
    'so you want me to',
    'you want me to',
    "you'd like me to",
    'you need me to',
  ];

  /// Carriers for a question, where the reflection is the subject rather than
  /// an action — "you want to know about your gate".
  static const _questionCarriers = <String>[
    'you want to know about',
    "you're asking about",
    'you want the details on',
  ];

  static const _holds = <String>[
    'Let me get that for you.',
    'Let me pull that up.',
    'Give me a moment.',
    "I'll check that now.",
    'One moment while I look that up.',
    'Just a second while I check.',
  ];

  /// Said when the passenger has approved something the assistant asked about.
  ///
  /// Kept apart from the request pools because a spoken "yes" carries no
  /// content to reflect, and because this is the one moment where the
  /// passenger most needs to hear that the approval landed.
  static const _confirmations = <String>[
    'Alright, confirming that now.',
    "Okay, I'll go ahead with that.",
    'Sure, putting that through now.',
    "Right, I'm confirming it.",
  ];

  /// Said when the passenger turns down something the assistant asked about.
  ///
  /// Audio mode has no confirmation bar to visibly disappear, so without a
  /// spoken line a "no" produces total silence — the passenger cannot tell
  /// their refusal registered from the microphone having missed it entirely.
  static const _declines = <String>[
    "Okay, I've left it as it was.",
    'No problem, nothing has changed.',
    "Alright, I won't do that.",
    "Sure, I've left that alone.",
  ];

  /// Said when a passenger answers a pending question with something else
  /// entirely, which drops the approval that was waiting.
  ///
  /// In the chat the confirmation bar simply vanishes and the passenger can see
  /// it go. Spoken, the fact has to be stated or the next "yes" lands on
  /// nothing and gets posted to the backend as a fresh request.
  static const _dropped = <String>[
    "I'll leave that unconfirmed for now.",
    "I haven't gone ahead with that, by the way.",
    "That one's still not confirmed.",
  ];

  /// Holds that name what is about to be looked at, chosen on a keyword in the
  /// request.
  ///
  /// Every one of these states an intention rather than a fact — "let me look
  /// at the seats", never "your seat is free". Nothing here has seen a backend
  /// response yet, so anything stronger would be a guess spoken confidently.
  static const _topicHolds = <String, List<String>>{
    'seat': ['Let me look at the seats.', 'Pulling up the seat map now.'],
    'bag': [
      'Let me look at the baggage options.',
      'Checking the baggage side of things.',
    ],
    'flight': ['Let me check the flights.', 'Looking at the flights now.'],
    'fare': ['Let me look at the fares.', 'Checking the pricing now.'],
    'booking': [
      'Let me pull up the booking.',
      'Looking at the booking details now.',
    ],
    'airport': [
      'Let me check the airport information.',
      'Looking that up at the airport now.',
    ],
    'weather': ['Let me check the weather.', 'Looking at the forecast now.'],
    'hotel': ['Let me look at the stays.', 'Checking what is available.'],
  };

  /// Which keyword each topic answers to. Several words map onto one hold, and
  /// the order matters: the first match wins, so the more specific words are
  /// listed before the ones that appear in almost every travel request.
  static const _topicKeywords = <String, String>{
    'seat': 'seat',
    'aisle': 'seat',
    'window': 'seat',
    'bag': 'bag',
    'baggage': 'bag',
    'luggage': 'bag',
    'suitcase': 'bag',
    'weather': 'weather',
    'forecast': 'weather',
    'hotel': 'hotel',
    'stay': 'hotel',
    'gate': 'airport',
    'terminal': 'airport',
    'airport': 'airport',
    'lounge': 'airport',
    'fare': 'fare',
    'price': 'fare',
    'cheapest': 'fare',
    'cost': 'fare',
    'booking': 'booking',
    'itinerary': 'booking',
    'reservation': 'booking',
    'pnr': 'booking',
    'flight': 'flight',
    'flights': 'flight',
    'fly': 'flight',
    'flying': 'flight',
  };

  /// Fillers people open with, which carry nothing worth restating.
  static final _leadIn = RegExp(
    r"^(hey|hi|hello|ok|okay|so|um|uh|well|please|actually|just|now)\b[,\s]*",
    caseSensitive: false,
  );

  /// "Can you…", "could you please…" — the frame around the request rather
  /// than the request.
  static final _politeFrame = RegExp(
    r'^(can|could|would|will|do)\s+you\s+(please\s+)?',
    caseSensitive: false,
  );

  /// "I want to…", "I'd like you to…" — first-person framing of the same.
  static final _wantFrame = RegExp(
    r"^i\s+(want|need|would\s+like|'?d\s+like|wanna)\s+(you\s+)?(to\s+)?",
    caseSensitive: false,
  );

  /// Verbs that make what follows an instruction this can restate as-is.
  static final _imperative = RegExp(
    r'^(show|tell|give|find|get|book|check|change|cancel|add|remove|search|'
    r'look|pull|bring|help|list|read|update|move|pick|choose|upgrade|reschedule)'
    r'\b',
    caseSensitive: false,
  );

  static final _question = RegExp(
    r"^(what|what's|when|when's|where|where's|which|how|who|why|is|are|do|does|"
    r'did|can|has|have)\b',
    caseSensitive: false,
  );

  /// The passenger's noun in a question — the "my gate" of "what's my gate".
  static final _ownedNoun = RegExp(r'\bmy\s+([a-z]+)\b', caseSensitive: false);

  /// Words that extend the noun above rather than doing something to it.
  ///
  /// Taking any second word would swallow the verb — "when does my flight
  /// leave" would come back as "your flight leave" — so only these follow.
  static const _nounTails = <String>{
    'number',
    'status',
    'time',
    'times',
    'details',
    'options',
    'allowance',
    'code',
    'pass',
    'map',
    'booking',
    'bookings',
    'reference',
    'gate',
    'seat',
    'flight',
  };

  /// First person from the passenger's mouth becomes second person from the
  /// assistant's: "help me with my trip" is heard back as "help you with your
  /// trip".
  static const _flipped = <String, String>{
    'i': 'you',
    'me': 'you',
    'my': 'your',
    'mine': 'yours',
    'myself': 'yourself',
    'we': 'you',
    'us': 'you',
    'our': 'your',
    'ours': 'yours',
    "i'm": "you're",
    "i've": "you've",
    "i'd": "you'd",
    "i'll": "you'll",
    'im': "you're",
  };

  /// The line to speak while [transcript] is being answered.
  ///
  /// Pass [confirming] when the transcript is a "yes" to something the
  /// assistant asked about — an approval has nothing to read back, and needs to
  /// be heard as landing rather than as a new request.
  ///
  /// Returns an empty string only for an empty transcript. Silence is what this
  /// exists to remove, so anything the reflection cannot handle still gets an
  /// opener and a hold.
  String compose(String transcript, {bool confirming = false}) {
    final cleaned = _clean(transcript);
    if (cleaned.isEmpty) return '';
    if (confirming) return _pick(_confirmations);

    final opener = _pick(_openers);
    final reflection = _reflect(cleaned);
    final hold = _holdFor(cleaned);

    return reflection == null
        ? '$opener. $hold'
        : '$opener, $reflection. $hold';
  }

  /// The line to speak when the passenger turns a pending action down.
  ///
  /// Nothing is fetched for a refusal, so this is the whole of the turn — the
  /// alternative is silence, which is indistinguishable from not being heard.
  String composeDecline() => _pick(_declines);

  /// Prefixes [acknowledgement] with a note that the approval the assistant was
  /// waiting on has lapsed.
  ///
  /// Folded into the line already being spoken rather than queued as a second
  /// utterance, so the passenger hears one sentence about their new request
  /// instead of two competing ones.
  String composeDropped(String acknowledgement) {
    final note = _pick(_dropped);
    final rest = acknowledgement.trim();
    return rest.isEmpty ? note : '$note $rest';
  }

  /// The backend's follow-ups, worded as something to say rather than
  /// something to tap.
  ///
  /// Audio mode has no chips in the passenger's eyeline — and often no
  /// eyeline at all — so without this, whole steps of the journey are
  /// undiscoverable: nothing tells you that checking in or upgrading is on
  /// offer.
  ///
  /// Capped at two. The backend routinely sends four, and reading a menu back
  /// after every answer turns a conversation into an IVR tree.
  static String composeSuggestionLine(List<String> suggestions) {
    final offered = suggestions
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(2)
        .map(_lowerFirst)
        .toList();

    return switch (offered.length) {
      0 => '',
      1 => 'You could ${offered.first}.',
      _ => 'You could ${offered.first}, or ${offered.last}.',
    };
  }

  /// Folds a chip label into the middle of a sentence. Leaves an acronym alone
  /// — "PNR" must not become "pNR".
  static String _lowerFirst(String label) {
    final firstWord = label.split(' ').first;
    if (firstWord.length > 1 && firstWord == firstWord.toUpperCase()) {
      return label;
    }
    return label[0].toLowerCase() + label.substring(1);
  }

  /// The pools, so a test can assert which kind of line was produced without
  /// depending on which one [_pick] happened to choose.
  @visibleForTesting
  static const declineLines = _declines;

  @visibleForTesting
  static const droppedNotes = _dropped;

  /// What the assistant understood, as a clause — "you want me to change your
  /// seat" — or `null` when the request is not one of the shapes that can be
  /// restated safely.
  String? _reflect(String request) {
    var rest = request;
    // Repeated, because people stack them: "okay so can you…".
    while (_leadIn.hasMatch(rest)) {
      final stripped = rest.replaceFirst(_leadIn, '').trim();
      if (stripped.isEmpty) return null;
      rest = stripped;
    }

    final asQuestion = _question.hasMatch(rest);
    rest = rest
        .replaceFirst(_politeFrame, '')
        .replaceFirst(_wantFrame, '')
        .trim();
    if (rest.isEmpty) return null;
    if (rest.split(' ').length > maxReflectedWords) return null;

    // "Can you tell me my gate" reads as an instruction once the frame is off,
    // even though it opened as a question — so the imperative is checked first.
    if (_imperative.hasMatch(rest)) {
      return '${_pick(_requestCarriers)} ${_flip(rest)}';
    }

    if (asQuestion) {
      // A question is only reflected when the passenger named something of
      // their own in it. "What's the weather in Paris" has no such subject, and
      // restating the question itself would need grammar this does not have.
      final match = _ownedNoun.firstMatch(rest);
      if (match == null) return null;
      return '${_pick(_questionCarriers)} your ${_ownedPhrase(rest, match)}';
    }

    return null;
  }

  /// The noun the passenger asked about, extended by one word when the next
  /// one belongs to it — "gate", but "gate number".
  String _ownedPhrase(String rest, RegExpMatch match) {
    final noun = match.group(1)!;
    final after = rest.substring(match.end).trim().split(' ');
    final tail = after.isEmpty ? '' : after.first;
    return _nounTails.contains(tail) ? '$noun $tail' : noun;
  }

  /// A hold phrase, preferring one that names what is being looked at.
  String _holdFor(String request) {
    for (final word in request.split(' ')) {
      final topic = _topicKeywords[word];
      if (topic != null) return _pick(_topicHolds[topic]!);
    }
    return _pick(_holds);
  }

  String _flip(String phrase) => phrase
      .split(' ')
      .map((word) => _flipped[word] ?? word)
      .join(' ');

  /// Lower-cased and stripped of everything but words and apostrophes.
  ///
  /// This is recognizer output on its way back to a speech engine: it is never
  /// read, so case carries nothing, and stray punctuation only breaks the
  /// word-level matching below.
  String _clean(String transcript) => transcript
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// A random entry from [pool], never the one this pool gave last.
  String _pick(List<String> pool) {
    if (pool.length == 1) return pool.first;
    final last = _lastPicks[pool];
    var index = _random.nextInt(pool.length);
    if (index == last) index = (index + 1) % pool.length;
    _lastPicks[pool] = index;
    return pool[index];
  }
}
