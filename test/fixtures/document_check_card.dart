/// Real `document_check` card, captured from live `POST /api/v1/chat` on
/// 2026-08-13 as member `9BX37KM` (Marcus Bennett).
///
/// **The trigger phrase is narrow.** Only "is my passport OK for this trip"
/// produced this card. "show me everyone's documents", "check our passports
/// for Japan" and "are our documents ready" all came back with `tool: null`
/// and the generic capability reply — so the demo script must use the exact
/// wording, and the card is not reachable by paraphrase.
///
/// Shape notes for the mapper:
/// - passengers are split across two lists, `ok` and `issues`, not one list
///   with a status field
/// - `ok` rows carry only `passenger` + `expiry`
/// - `issues` rows carry `issue`, `severity`, `detail` and a remedial
///   `action`
/// - `ready` is the overall verdict
const documentCheckCardFixture = <String, Object?>{
  'type': 'document_check',
  'destination': 'Tokyo',
  'rule': 'passport_valid_for_stay',
  'ruleDetail': 'Passport must be valid for the entire period of stay. '
      'No visa for US tourists under 90 days.',
  'depart': '2027-04-04',
  'return': '2027-04-15',
  'ok': <Object?>[
    <String, Object?>{'passenger': 'Marcus Bennett', 'expiry': '2031-02-17'},
    <String, Object?>{'passenger': 'Priya Bennett', 'expiry': '2032-11-01'},
  ],
  'issues': <Object?>[
    <String, Object?>{
      'passenger': 'Leo Bennett',
      'issue': 'no_passport',
      'severity': 'blocking',
      'detail': 'Leo has no passport on file.',
      'action': 'First-time minor passport — typically 6–8 weeks; '
          'both parents must be present.',
    },
    <String, Object?>{
      'passenger': 'Zoe Bennett',
      'issue': 'expires_before_return',
      'severity': 'blocking',
      'detail': 'Passport expires 2027-04-09, before the return on 2027-04-15.',
      'action': 'Renew before departure; expedited appointments are available.',
    },
  ],
  'ready': false,
};

/// The turn the card arrived on — note `tool: 'check_documents'`.
const documentCheckTurnFixture = <String, Object?>{
  'reply': '2 document issue(s): Leo — Leo has no passport on file. '
      'Zoe — Passport expires 2027-04-09, before the return on 2027-04-15.',
  'cards': <Object?>[documentCheckCardFixture],
  'tool': 'check_documents',
  'needsConfirmation': false,
};

/// The prompt that actually triggers the card. Kept next to the fixture so
/// the demo script and the tests cannot drift apart.
const documentCheckTriggerPhrase = 'is my passport OK for this trip';
