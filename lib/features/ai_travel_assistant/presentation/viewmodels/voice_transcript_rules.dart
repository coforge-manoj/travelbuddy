/// Pure decisions about a transcript, kept out of the controller so they can be
/// tested without a state machine, a microphone, or a clock.
library;

/// Words that carry the actual "yes" — an utterance needs at least one.
const _affirmationCore = <String>{
  'yes',
  'yeah',
  'yep',
  'yup',
  'sure',
  'ok',
  'okay',
  'confirm',
  'confirmed',
  'proceed',
  'ahead',
  'book',
};

/// Words that may accompany a yes without changing its meaning.
///
/// People rarely say a bare "yes" — "yes, go ahead", "okay, book it", "yeah
/// that works" are all far more natural. Matching whole phrases from a fixed
/// list missed every one of those, so instead the whole utterance must be built
/// only from these words plus at least one from [_affirmationCore].
///
/// The safety property is that *any* unrecognized word disqualifies the
/// utterance. "Yes but change the date first" contains `but`, `change`, `date`,
/// `first` and so is sent to the backend as a normal message rather than
/// approving a booking the passenger was about to alter. This is the one place
/// in the journey where guessing wrong spends money.
const _affirmationFiller = <String>{
  'go',
  'do',
  'it',
  'that',
  'please',
  'works',
  'sounds',
  'good',
  'fine',
  'lets',
  "let's",
  'us',
  'all',
  'right',
  'thanks',
  'thank',
  'you',
  // "yes, upgrade me" / "yes, book my seat" — the pronoun the passenger
  // attaches to the action verb.
  'me',
  'my',
};

const _declineCore = <String>{
  'no',
  'nope',
  'nah',
  'not',
  'never',
  'nevermind',
  'cancel',
  'stop',
  'forget',
  'skip',
  'leave',
  "don't",
  'dont',
};

const _declineFiller = <String>{
  'now',
  'mind',
  'it',
  'that',
  'this',
  'yet',
  'thanks',
  'thank',
  'you',
  'please',
  'do',
  'lets',
  "let's",
};

bool _matches(
  String transcript,
  Set<String> core,
  Set<String> filler,
  Set<String> alsoAllowed,
) {
  final words = _normalize(transcript).split(' ').where((w) => w.isNotEmpty);
  if (words.isEmpty) return false;

  var sawCore = false;
  for (final word in words) {
    if (core.contains(word)) {
      sawCore = true;
      continue;
    }
    if (!filler.contains(word) && !alsoAllowed.contains(word)) return false;
  }
  return sawCore;
}

/// The words of whatever the assistant is currently asking about.
///
/// People answer a question using the words of the question — "yes, cancel it",
/// "yes, upgrade me". Without this those utterances match nothing: the action's
/// own verb is not filler, and any unrecognized word disqualifies the whole
/// phrase. Worse, `cancel` is itself a *decline* word, so the most natural way
/// to approve a cancellation read as neither an approval nor a refusal and was
/// posted to the backend as a brand new request.
///
/// Scoped to the pending action on purpose, never merged into the global sets.
/// `cancel` means "call it off" when a booking is awaiting approval and "do the
/// thing" when a cancellation is — so allowing it everywhere would turn "yes,
/// cancel" into an approval of the booking the passenger was trying to stop.
Set<String> _actionWords(String pendingAction) {
  if (pendingAction.trim().isEmpty) return const {};
  return _normalize(pendingAction).split(' ').where((w) => w.isNotEmpty).toSet();
}

String _normalize(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Whether [transcript] approves a pending action.
///
/// The whole utterance has to be affirmative. "Yes, but change the date first"
/// is a new request, not an approval, and treating it as one would book the
/// wrong thing.
///
/// [pendingAction] is what the assistant is waiting on — e.g. `cancel my
/// booking` — whose own words are then allowed alongside the yes. See
/// [_actionWords] for why that is scoped rather than global.
bool isAffirmation(String transcript, {String pendingAction = ''}) => _matches(
      transcript,
      _affirmationCore,
      _affirmationFiller,
      _actionWords(pendingAction),
    );

/// Whether [transcript] rejects a pending action.
///
/// Takes [pendingAction] for the same reason as [isAffirmation] — "no, don't
/// cancel it" needs the verb to be sayable. Safe in the other direction too:
/// declining only drops local state, so a false positive costs a repeated
/// question rather than money.
bool isDecline(String transcript, {String pendingAction = ''}) => _matches(
      transcript,
      _declineCore,
      _declineFiller,
      _actionWords(pendingAction),
    );

/// Whether [transcript] is the microphone hearing the assistant rather than
/// the passenger.
///
/// Half-duplex means the microphone is closed while audio plays, but the
/// speaker keeps ringing for a moment after playback ends and the recognizer
/// can catch the tail. Such a transcript arrives almost immediately and repeats
/// words the assistant just said — neither signal is reliable alone, so both
/// are required.
///
/// [sinceReopened] is how long the microphone has been open; [window] is how
/// long after reopening an echo is still plausible.
bool looksLikeEcho(
  String transcript,
  String lastSpokenLine, {
  required Duration sinceReopened,
  Duration window = const Duration(milliseconds: 600),
  double overlapThreshold = 0.6,
}) {
  if (sinceReopened > window) return false;
  if (lastSpokenLine.trim().isEmpty) return false;

  final heard = _normalize(transcript).split(' ').where((w) => w.isNotEmpty);
  if (heard.isEmpty) return false;

  final spoken = _normalize(lastSpokenLine).split(' ').toSet();
  if (spoken.isEmpty) return false;

  final overlap = heard.where(spoken.contains).length / heard.length;
  return overlap >= overlapThreshold;
}

/// Recognizer error codes that mean "nobody said anything".
///
/// These are the normal outcome of a passenger pausing, not faults: the loop
/// counts them and asks again rather than surfacing an error.
const _silenceErrors = <String>{
  'error_speech_timeout',
  'error_no_match',
  'error_retry',
};

bool isSilenceError(String errorCode) =>
    _silenceErrors.contains(errorCode.trim().toLowerCase());
