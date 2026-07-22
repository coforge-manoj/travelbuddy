import 'package:equatable/equatable.dart';

class EscalationRequest extends Equatable {
  const EscalationRequest({
    required this.reason,
    required this.conversationSummary,
    this.confidence,
  });

  final String reason;
  final String conversationSummary;
  final double? confidence;

  @override
  List<Object?> get props => [reason, conversationSummary, confidence];
}

class EscalationResult extends Equatable {
  const EscalationResult({required this.queuePosition, required this.estimatedWaitMinutes});

  final int queuePosition;
  final int estimatedWaitMinutes;

  @override
  List<Object?> get props => [queuePosition, estimatedWaitMinutes];
}
