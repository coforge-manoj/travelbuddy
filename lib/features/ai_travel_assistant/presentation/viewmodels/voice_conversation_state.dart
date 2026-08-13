import 'package:equatable/equatable.dart';

/// Where the hands-free conversation is in its cycle.
///
/// Deliberately separate from `ChatStatus`, which describes a *turn*
/// (idle/sending/error). This describes the loop, which outlives any one turn
/// and has concerns a turn does not: when to reopen the microphone, how many
/// times in a row the passenger has said nothing, and whether an interruption
/// has orphaned work that is still in flight.
enum VoicePhase {
  /// Audio mode is open but the microphone is closed — the state after an
  /// interruption, or after the passenger has been silent too many times.
  idle,

  /// Asking the platform for the microphone. First time through, this is where
  /// the permission prompt appears.
  preparing,

  /// Microphone open, nothing heard yet.
  listening,

  /// Microphone open and words are arriving. Split from [listening] so the UI
  /// can show a live transcript, and so silence handling can tell "said
  /// nothing" apart from "started and stopped".
  capturing,

  /// The turn has been sent; the backend and the synthesizer are working.
  thinking,

  /// Audio is playing. The microphone stays closed until it finishes.
  speaking,

  /// Something recoverable went wrong. Returns to [listening] on its own.
  recovering,

  /// The microphone was refused. Terminal — only the passenger can resolve it,
  /// from system settings.
  permissionDenied,
}

class VoiceConversationState extends Equatable {
  const VoiceConversationState({
    this.phase = VoicePhase.idle,
    this.partialTranscript = '',
    this.lastSpokenLine = '',
    this.message,
    this.consecutiveSilentTurns = 0,
  });

  final VoicePhase phase;

  /// What the recognizer has heard so far this turn, for the live caption.
  final String partialTranscript;

  /// The last thing the assistant said, kept for the echo guard: a transcript
  /// that arrives immediately after speech and echoes it is the microphone
  /// hearing the speaker, not the passenger talking.
  final String lastSpokenLine;

  /// Something to show the passenger — why the loop stopped, or what to do
  /// about a refused microphone.
  final String? message;

  /// How many turns in a row have produced nothing. The loop gives up after a
  /// couple rather than reopening the microphone forever at someone who has
  /// put the phone down.
  final int consecutiveSilentTurns;

  /// Whether the microphone is open.
  bool get isListening =>
      phase == VoicePhase.listening || phase == VoicePhase.capturing;

  /// Whether the loop is running, in the sense that it will act on its own
  /// again without the passenger tapping anything.
  bool get isActive =>
      phase != VoicePhase.idle && phase != VoicePhase.permissionDenied;

  VoiceConversationState copyWith({
    VoicePhase? phase,
    String? partialTranscript,
    String? lastSpokenLine,
    String? message,
    bool clearMessage = false,
    int? consecutiveSilentTurns,
  }) {
    return VoiceConversationState(
      phase: phase ?? this.phase,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      lastSpokenLine: lastSpokenLine ?? this.lastSpokenLine,
      message: clearMessage ? null : (message ?? this.message),
      consecutiveSilentTurns:
          consecutiveSilentTurns ?? this.consecutiveSilentTurns,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        partialTranscript,
        lastSpokenLine,
        message,
        consecutiveSilentTurns,
      ];
}
