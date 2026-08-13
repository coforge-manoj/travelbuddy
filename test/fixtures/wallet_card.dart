/// Real `wallet` card, captured from live `POST /api/v1/chat` on 2026-08-13
/// as member `9BX37KM` (Marcus Bennett) with the message
/// "can we do this on miles" — the Journey A step 1 prompt.
///
/// **This is not a [WalletSplit].** The embedded `wallet` block on
/// `basket` / `flight_selected` / `booking_confirmed` describes amounts
/// *applied* to a payment (voucher/miles/card `applied` figures). This card
/// describes the methods *on file* — a balance, not a split — so it needs
/// its own entity and widget rather than reusing `WalletSplitSection`.
///
/// `voucher` came back `null` for this member; the mapper must tolerate that
/// rather than assuming every wallet has one.
const walletCardFixture = <String, Object?>{
  'type': 'wallet',
  'miles': 214000,
  'voucher': null,
  'card': <String, Object?>{
    'brand': 'Citi',
    'last4': '4417',
  },
  'tier': 'Platinum Pro',
  'loyaltyPoints': 121500,
};

/// The turn the card arrived on, for tests that need the envelope rather
/// than just the card — note `tool: 'get_wallet'`.
const walletTurnFixture = <String, Object?>{
  'reply': '214,000 miles, card ending 4417.',
  'cards': <Object?>[walletCardFixture],
  'tool': 'get_wallet',
  'needsConfirmation': false,
  'suggestions': <String>[
    'Flights from ATL',
    'My miles',
    'My bookings',
    'What needs my attention?',
  ],
};
