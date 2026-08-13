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

bool _matches(String transcript, Set<String> core, Set<String> filler) {
  final words = _normalize(transcript).split(' ').where((w) => w.isNotEmpty);
  if (words.isEmpty) return false;

  var sawCore = false;
  for (final word in words) {
    if (core.contains(word)) {
      sawCore = true;
      continue;
    }
    if (!filler.contains(word)) return false;
  }
  return sawCore;
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
bool isAffirmation(String transcript) =>
    _matches(transcript, _affirmationCore, _affirmationFiller);

/// Whether [transcript] rejects a pending action.
bool isDecline(String transcript) =>
    _matches(transcript, _declineCore, _declineFiller);

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
