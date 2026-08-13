import 'package:ai_travel_assistant/features/ai_travel_assistant/data/mappers/card_json.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/document_check.dart';

/// Reads the `document_check` card — passport readiness per passenger against
/// the destination's entry rule.
class DocumentCheckCardMapper {
  const DocumentCheckCardMapper._();

  static const documentCheckCardType = 'document_check';

  /// Returns `null` when no passenger appears on either list, so the caller
  /// falls back to the reply text rather than drawing an empty card.
  static DocumentCheck? fromCard(Map<String, dynamic> card) {
    final clear = CardJson.asMapList(CardJson.pick(card, ['ok', 'clear']))
        .map(_clearance)
        .whereType<DocumentClearance>()
        .toList(growable: false);

    final issues =
        CardJson.asMapList(CardJson.pick(card, ['issues', 'problems']))
            .map(_issue)
            .whereType<DocumentIssue>()
            .toList(growable: false);

    if (clear.isEmpty && issues.isEmpty) return null;

    return DocumentCheck(
      destination:
          CardJson.asString(CardJson.pick(card, ['destination', 'dest'])),
      ruleDetail:
          CardJson.asString(CardJson.pick(card, ['ruleDetail', 'ruleText'])),
      depart: CardJson.asString(CardJson.pick(card, ['depart', 'departDate'])),
      returnDate:
          CardJson.asString(CardJson.pick(card, ['return', 'returnDate'])),
      // Trust the backend's verdict when it sends one; otherwise an issue
      // list is itself proof the party is not ready.
      ready: CardJson.asBoolOrNull(CardJson.pick(card, ['ready'])) ??
          issues.isEmpty,
      clear: clear,
      issues: issues,
    );
  }

  static DocumentClearance? _clearance(Map<String, dynamic> json) {
    final passenger =
        CardJson.asString(CardJson.pick(json, ['passenger', 'name']));
    if (passenger == null) return null;
    return DocumentClearance(
      passenger: passenger,
      expiry: CardJson.asString(CardJson.pick(json, ['expiry', 'expires'])),
    );
  }

  static DocumentIssue? _issue(Map<String, dynamic> json) {
    final passenger =
        CardJson.asString(CardJson.pick(json, ['passenger', 'name']));
    if (passenger == null) return null;
    return DocumentIssue(
      passenger: passenger,
      issue: CardJson.asString(CardJson.pick(json, ['issue', 'code'])),
      severity: CardJson.asString(CardJson.pick(json, ['severity'])),
      detail: CardJson.asString(CardJson.pick(json, ['detail', 'message'])),
      action:
          CardJson.asString(CardJson.pick(json, ['action', 'remedy', 'fix'])),
    );
  }
}
