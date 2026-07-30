import 'package:dio/dio.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/spoken_draft.dart';

abstract interface class VoicePhrasingRemoteDataSource {
  Future<String> phrase({
    required SpokenDraft draft,
    required List<String> recentlySpoken,
  });
}

/// The instruction sent alongside every draft. Kept here rather than in the
/// domain because it is provider prompt text, not a business rule.
///
/// The two hard constraints exist because this copy is spoken, not read: the
/// passenger cannot re-read a mangled fare, and a model that invents a gate
/// number is worse than one that sounds repetitive. `SpokenFactGuard` verifies
/// the result regardless of whether the model complied.
const _voicePhrasingStyleGuide = '''
You are the voice of an airline travel assistant, speaking to a passenger.
Rewrite the given facts as ONE short spoken turn.

Rules:
- Convey every fact. Never add a fact, a number, a price, a time, or a code
  that is not in the list. Copy the "must_include" fragments exactly.
- 2 sentences where possible, 3 at the very most. This is spoken aloud.
- Warm, polite and calm. Offer, never instruct: "would you like" rather than
  "say" or "you must". Never apologise twice in one turn.
- End by inviting the passenger to do what "invitation" describes, in your own
  words. Ask at most one question.
- Vary your wording from "recent_utterances" — do not reuse their openers.
- Plain prose only: no lists, markdown, emoji, or stage directions.
''';

/// Provider-agnostic phrasing call. Uses the same `/chat` surface and
/// [Dio] instance as [OpenAiChatRemoteDataSource], so swapping providers stays
/// a DI-level change.
class LlmVoicePhrasingRemoteDataSource implements VoicePhrasingRemoteDataSource {
  LlmVoicePhrasingRemoteDataSource(this._dio, {this.model = 'gpt-4.1-mini'});

  final Dio _dio;
  final String model;

  @override
  Future<String> phrase({
    required SpokenDraft draft,
    required List<String> recentlySpoken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/message',
      data: {
        'model': model,
        'mode': 'voice_phrasing',
        'instructions': _voicePhrasingStyleGuide,
        'topic': draft.topic.name,
        'tone': draft.tone.name,
        'invitation': draft.invitation.name,
        'facts': draft.clauses,
        'must_include': draft.mustInclude,
        'recent_utterances': recentlySpoken,
      },
    );

    final text = response.data?['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('Voice phrasing response had no text.');
    }
    return text.trim();
  }
}

/// Stands in for the phrasing model until a real endpoint is wired in.
///
/// It is not a stub that echoes the fallback: it recomposes the draft's facts
/// with a rotating frame, opener, and invitation so consecutive turns on the
/// same topic genuinely differ. That makes the behaviour audible in the demo,
/// and it exercises the same guard the real model's output goes through.
class MockVoicePhrasingRemoteDataSource implements VoicePhrasingRemoteDataSource {
  MockVoicePhrasingRemoteDataSource({
    this.latency = const Duration(milliseconds: 150),
  });

  /// Small on purpose — this sits between the passenger's request and the
  /// first spoken word.
  final Duration latency;

  /// Turns taken per topic, so the same card never comes back word-for-word
  /// the way the old fixed summaries did.
  final Map<SpokenTopic, int> _turns = {};

  @override
  Future<String> phrase({
    required SpokenDraft draft,
    required List<String> recentlySpoken,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final turn = _turns.update(draft.topic, (value) => value + 1, ifAbsent: () => 0);
    final clauses = draft.clauses.where((clause) => clause.trim().isNotEmpty).toList();
    if (clauses.isEmpty) return draft.fallbackText;

    final openers = _openersFor(draft.tone, isFollowUp: recentlySpoken.isNotEmpty);
    final frames = _framesFor(draft.tone);

    // Different strides so the frame, opener, and closing question don't
    // advance in lockstep and re-pair themselves every few turns.
    final opener = openers[(turn * 2 + 1) % openers.length];
    final frame = frames[turn % frames.length];
    final body = frame(opener, clauses);

    final invitations = _invitations[draft.invitation]!;
    if (invitations.isEmpty) return body;
    return '$body ${_pickInvitation(invitations, turn, opener)}';
  }

  /// Avoids closing on the same distinctive word the turn opened with —
  /// "Lovely, … Have a lovely trip." is the kind of echo a person would hear.
  static String _pickInvitation(List<String> invitations, int turn, String opener) {
    final index = (turn * 3) % invitations.length;
    final echo = opener.toLowerCase().split(' ').last;
    if (echo.length >= 4 && invitations[index].toLowerCase().contains(echo)) {
      return invitations[(index + 1) % invitations.length];
    }
    return invitations[index];
  }

  static List<String> _openersFor(SpokenTone tone, {required bool isFollowUp}) {
    return switch (tone) {
      // Openers have to read naturally both mid-sentence and as a sentence of
      // their own, since the frames use them both ways.
      SpokenTone.neutral => isFollowUp
          ? const ['Right', 'Okay then', 'Now then', 'Good']
          : const ['Right then', 'Okay', 'Here we are', 'All right'],
      SpokenTone.apologetic => const ["I'm sorry", "I'm afraid", 'Unfortunately'],
      SpokenTone.reassuring => const ['Of course', 'Not to worry', 'Certainly'],
      SpokenTone.celebratory => const ['Wonderful', 'Lovely', 'All set', 'Perfect'],
    };
  }

  /// A tone's opener carries its feeling, so only neutral turns may drop it.
  static List<_PhrasingFrame> _framesFor(SpokenTone tone) {
    return tone == SpokenTone.neutral ? _frames : _frames.sublist(0, _frames.length - 1);
  }

  static final List<_PhrasingFrame> _frames = [
    (opener, clauses) => '$opener — ${_join(clauses)}.',
    (opener, clauses) => '$opener. ${_capitalize(_join(clauses))}.',
    // Breaks the last fact off into its own sentence, so a turn carrying
    // several facts doesn't arrive as one long list. Splitting at the tail
    // rather than the head keeps the leading facts grouped, which is how they
    // were written to read.
    (opener, clauses) => clauses.length < 3
        ? '$opener, ${_join(clauses)}.'
        : '$opener, ${_join(clauses.sublist(0, clauses.length - 1))}. '
            '${_capitalize(clauses.last)}.',
    (_, clauses) => '${_capitalize(_join(clauses))}.',
  ];

  static const _invitations = <SpokenInvitation, List<String>>{
    SpokenInvitation.none: [],
    SpokenInvitation.chooseOffer: [
      'Would you like that one, or would you prefer a different airline?',
      'Shall I go ahead with that, or would you rather hear the others?',
      "I'm happy to book that one, or to find you another.",
      'Would you like me to take that one, or look through the rest with you?',
    ],
    SpokenInvitation.confirmSingleOffer: [
      'Would you like me to book it for you?',
      'Shall I go ahead and book that?',
      "I'm happy to book it whenever you're ready.",
      'Would you like me to secure that for you?',
    ],
    SpokenInvitation.chooseSeat: [
      'Would you like a window, an aisle, or a particular seat?',
      'Shall I find you a window, or would you rather pick one yourself?',
      'A window or an aisle, or name a seat — whichever is easier.',
      'Would you prefer a window seat or an aisle seat?',
    ],
    SpokenInvitation.chooseBaggage: [
      'Which would you prefer?',
      'Which of those suits you best?',
      'Would any of those work for you?',
      "Just let me know which you'd like.",
    ],
    SpokenInvitation.offerOtherDates: [
      'Would you like to try a different date, or another destination?',
      'Shall I look at other days for you?',
      "I'm happy to check another date or route if you like.",
      'Would a different day work for you?',
    ],
    SpokenInvitation.anythingElse: [
      'Is there anything else I can help you with?',
      'Anything else I can do for you?',
      'Do let me know if you need anything else.',
      "I'm happy to help with anything else.",
    ],
    SpokenInvitation.awaitAgent: [
      'Do stay with me and I will pass you across.',
      'Please stay on the line and I will hand you over.',
      "I'll stay with you until someone picks up.",
    ],
    SpokenInvitation.wishWell: [
      'Have a wonderful trip.',
      'Enjoy your flight.',
      'Have a lovely trip.',
      'Safe travels, and enjoy the flight.',
    ],
  };

  static String _join(List<String> clauses) {
    if (clauses.length == 1) return clauses.single;
    if (clauses.length == 2) return '${clauses.first}, and ${clauses.last}';
    return '${clauses.sublist(0, clauses.length - 1).join(', ')}, and ${clauses.last}';
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

typedef _PhrasingFrame = String Function(String opener, List<String> clauses);
