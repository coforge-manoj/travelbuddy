import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/action_summary.dart';
import 'package:ai_travel_assistant/features/concierge_demo/domain/entities/proactive_scenario.dart';

/// The 12 scripted Journey Concierge use cases from the Bennett family's
/// Tokyo trip demo playbook (Inspire → Arrival). Content — situation,
/// notification copy, and every Parent/Concierge line — is transcribed
/// verbatim from the spec; only `matchKeywords` and the concluding
/// [ActionSummary] per scenario are authored here, since the spec doesn't
/// give those in a structured form.
final List<ProactiveScenario> scenarioCatalog = [
  // ---------------------------------------------------------------------
  // Inspire
  // ---------------------------------------------------------------------
  const ProactiveScenario(
    id: 'inspire-discovery',
    stage: TripStage.inspire,
    useCaseTitle: 'Natural-language destination discovery',
    situation:
        "Marcus and Priya are half-planning a trip to see Priya's parents but haven't nailed "
        "dates, cost, or whether points can offset the fare for four people. Today's AA app "
        'gives them only a route/date search box.',
    notificationText: 'Are you looking to plan a family trip to Tokyo?',
    turns: [
      ScenarioTurn(
        parentLine: 'Best time for our family of 4 to fly to Tokyo this spring, and can we use '
            'points for any of it?',
        matchKeywords: ['best time', 'tokyo', 'points', 'family of 4', 'cost'],
        conciergeReply:
            'For four travelers from Atlanta, late March to mid-April has the best fares and '
            "it's cherry blossom season. Connecting through DFW, a round trip runs about "
            '\$1,180 per person, or you can blend cash and AAdvantage miles — about 32,000 '
            'miles plus \$340 per person for two of you.',
      ),
      ScenarioTurn(
        parentLine: 'Can the kids sit with us?',
        matchKeywords: ['kids sit', 'seats together', 'sit with us'],
        conciergeReply:
            'Yes — I can hold four seats together on both legs, including the long '
            'DFW–Narita segment. Want me to check specific dates around spring break?',
      ),
      ScenarioTurn(
        parentLine: 'Yes, April 4th to 15th.',
        matchKeywords: ['april 4', 'april 15', 'spring break dates'],
        conciergeReply:
            'That week has availability on all four seats together, both directions. '
            "I'll save this as a trip plan so you can pick it back up whenever you're ready "
            'to book.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.bookmark,
      headline: 'Trip plan saved',
      details: [
        'Atlanta → Tokyo via DFW, Apr 4–15',
        '4 travelers, seats together on both legs',
        '≈\$1,180/person, or miles + cash blend',
      ],
      footer: '',
    ),
    availability: ScenarioAvailability.no,
  ),
  const ProactiveScenario(
    id: 'inspire-deal-alert',
    stage: TripStage.inspire,
    useCaseTitle: 'Proactive deal / award alert',
    situation:
        "Two weeks later, Marcus hasn't booked yet. He'd searched Tokyo a few times, so the "
        "app already knows the family's interest and dates. AA's app today only surfaces "
        'deals if a passenger goes looking.',
    notificationText: '✈️ Family trip to Tokyo, April 4–15: award seats just opened for all 4 '
        'of you. Mixing miles + cash saves about \$640 versus your last search — want me to '
        'hold it?',
    turns: [
      ScenarioTurn(
        parentLine: 'Yes — hold it, and remind me what the total cost looks like.',
        matchKeywords: ['hold it', 'total cost'],
        conciergeReply:
            'Holding four seats, April 4–15, ATL–DFW–NRT round trip. With miles + cash: '
            '128,000 AAdvantage miles plus \$1,360 total for the family. This is a 24-hour '
            'courtesy hold.',
      ),
      ScenarioTurn(
        parentLine: 'Do we have enough miles?',
        matchKeywords: ['enough miles', 'miles balance'],
        conciergeReply:
            'You have 214,000 miles — enough to cover this and still have some left over. '
            'Want me to apply them and lock in the booking now, before the hold expires?',
      ),
      ScenarioTurn(
        parentLine: 'Yes, book it.',
        matchKeywords: ['book it', 'confirm booking'],
        conciergeReply:
            'Booked ✅ All four seats confirmed together, April 4–15, ATL–DFW–NRT. '
            "I'll start prepping the trip — passports, seat selection and the DFW connection "
            'are next.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.checkCircle,
      headline: 'Booked ✅ — 4 seats confirmed',
      details: [
        'ATL → DFW → NRT round trip, Apr 4–15',
        '128,000 AAdvantage miles + \$1,360',
        'Next up: passports, seats, DFW connection',
      ],
    ),
    availability: ScenarioAvailability.no,
  ),

  // ---------------------------------------------------------------------
  // Book
  // ---------------------------------------------------------------------
  const ProactiveScenario(
    id: 'book-document-readiness',
    stage: TripStage.book,
    useCaseTitle: 'Proactive document/visa readiness at booking',
    situation:
        "Zoe's passport expires in 4 months — inside Japan's required validity window. Leo "
        "has never had a passport. The family doesn't know either fact, and AA's booking flow "
        'never checks.',
    notificationText: "🛂 Before you book: Leo doesn't have a passport on file, and Zoe's "
        'expires in 4 months. Japan requires passports valid through your full stay — '
        "let's get both sorted before you lock in dates.",
    turns: [
      ScenarioTurn(
        parentLine: "Wait, Zoe's passport is a problem? It's not expired.",
        matchKeywords: ['not expired', "zoe's passport"],
        conciergeReply:
            'Not expired, but Japan requires it valid for your entire visit, and Zoe\'s '
            "expires within your travel window. She'll need a renewal before April. Leo will "
            'need a first-time passport, typically 6–8 weeks.',
      ),
      ScenarioTurn(
        parentLine: "That's cutting it close. What do we do?",
        matchKeywords: ['cutting it close', 'what do we do'],
        conciergeReply:
            'You have time if you start this week — I can point you to expedited renewal '
            "appointments near Atlanta and give you the exact document checklist for a "
            "minor's first passport, since both parents need to be present.",
      ),
      ScenarioTurn(
        parentLine: 'Send us both checklists.',
        matchKeywords: ['send checklist', 'both checklists'],
        conciergeReply:
            'Done ✅ Sent to your email and saved to this trip. I\'ll set reminders at the '
            '6-week and 2-week marks so nothing slips before April 4th.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.passport,
      headline: 'Passport checklists sent ✅',
      details: [
        'Zoe: expedited renewal checklist',
        "Leo: first-time minor passport checklist (both parents required)",
        'Reminders set at the 6-week and 2-week marks',
      ],
    ),
    availability: ScenarioAvailability.no,
  ),
  const ProactiveScenario(
    id: 'book-dfw-connection',
    stage: TripStage.book,
    useCaseTitle: 'Tight-connection warning at booking (DFW)',
    situation:
        "AA's first-returned itinerary has a 55-minute DFW connection — domestic-to-"
        'international, with two kids, a stroller and full luggage for 11 days. AA shows the '
        "connection time but doesn't flag that it's tight for this transfer type.",
    notificationText: "🔗 Your DFW connection is 55 minutes — with two kids and an "
        "international terminal change, that's tighter than I'd recommend. A same-price "
        'option gives you 2h 10m instead. Want to see it?',
    turns: [
      ScenarioTurn(
        parentLine: 'Why does it matter that it\'s international?',
        matchKeywords: ['why international', 'matter'],
        conciergeReply:
            'Connecting to an international departure at DFW can mean a longer walk and, at '
            'busier times, an extra screening step. With Leo and Zoe and a stroller, 55 '
            'minutes leaves very little room if your first flight runs even slightly late.',
      ),
      ScenarioTurn(
        parentLine: "What's the alternative?",
        matchKeywords: ['alternative', 'other option'],
        conciergeReply:
            'Same flights, leaving Atlanta 90 minutes earlier — same fare, same seats '
            'together, and 2 hours 10 minutes in Dallas. Enough time for the kids to stretch '
            'and eat before an 11-hour flight.',
      ),
      ScenarioTurn(
        parentLine: "Let's do the longer connection.",
        matchKeywords: ['longer connection', "let's do it"],
        conciergeReply:
            "Switched ✅ You're now booked with a 2h 10m Dallas connection, same fare and "
            'four seats together on both legs. Much more comfortable with the kids.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.route,
      headline: 'Switched to the 2h 10m DFW connection ✅',
      details: [
        'Departs ATL 90 minutes earlier, same fare',
        '4 seats together on both legs',
      ],
    ),
    availability: ScenarioAvailability.no,
  ),

  // ---------------------------------------------------------------------
  // Pre-Trip
  // ---------------------------------------------------------------------
  const ProactiveScenario(
    id: 'pretrip-leave-by',
    stage: TripStage.preTrip,
    useCaseTitle: 'Personalized, family-paced "leave-by" time',
    situation:
        "The night before departure, Priya is anxious — she's never navigated ATL with two "
        "kids, a stroller, and 11 days of luggage. AA's app shows a boarding time and nothing "
        'else.',
    notificationText: '⏰ Family travel plan for tomorrow: leave home by 4:40 AM. That includes '
        'extra time for stroller and car-seat check and TSA with the kids — not just the '
        'drive.',
    turns: [
      ScenarioTurn(
        parentLine: 'That feels really early for a 7:15 flight.',
        matchKeywords: ['too early', 'really early'],
        conciergeReply:
            'It accounts for four people checking in, gate-checking Leo\'s stroller, and a '
            'family security lane that typically runs a bit slower. It also leaves buffer in '
            'case Saturday traffic is heavier than usual.',
      ),
      ScenarioTurn(
        parentLine: 'Will the stroller definitely be allowed to the gate?',
        matchKeywords: ['stroller', 'allowed to the gate'],
        conciergeReply:
            'Yes — strollers and car seats gate-check for free. I\'ll have the tags ready at '
            "check-in so that's one less thing to sort out tomorrow.",
      ),
      ScenarioTurn(
        parentLine: 'Okay, set the alert.',
        matchKeywords: ['set the alert', 'set alert'],
        conciergeReply:
            "Set ✅ You'll get a leave-now alert at 4:40 AM, adjusted live if traffic changes "
            "overnight. I'll also remind you where to gate-check the stroller when you "
            'arrive.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.clock,
      headline: 'Leave-by alert set for 4:40 AM ✅',
      details: [
        'Adjusts live with overnight traffic',
        'Stroller/car-seat gate-check tags ready at check-in',
      ],
    ),
    availability: ScenarioAvailability.no,
  ),
  const ProactiveScenario(
    id: 'pretrip-prep-bundle',
    stage: TripStage.preTrip,
    useCaseTitle: 'Destination-specific prep bundle (weather, culture, packing)',
    situation:
        "Neither Zoe nor Leo has been to Japan old enough to remember it. Marcus and the kids "
        "are flying blind on weather, etiquette and packing. AA's app offers nothing beyond "
        'the booking itself.',
    notificationText: '🌸 Tokyo in April: 16°C, cherry blossoms in bloom. Here are 3 things '
        'worth knowing before you land.',
    turns: [
      ScenarioTurn(
        parentLine: 'What should we pack?',
        matchKeywords: ['what to pack', 'packing'],
        conciergeReply:
            'Layers — mornings are cool, afternoons mild. Comfortable walking shoes matter '
            "more than anything else. A universal plug adapter too — Japan's outlets are "
            'different from home.',
      ),
      ScenarioTurn(
        parentLine: 'Anything the kids should know before we go?',
        matchKeywords: ['kids should know', 'etiquette'],
        conciergeReply:
            "A few etiquette basics kids pick up fast and grandparents will appreciate: "
            'bowing as a greeting, removing shoes indoors, quiet voices on trains. I can put '
            'together a one-pager for Zoe and Leo.',
      ),
      ScenarioTurn(
        parentLine: 'Yes, send that.',
        matchKeywords: ['send that', 'send it'],
        conciergeReply:
            'Done ✅ Sent a kid-friendly Japan primer to your email, plus packing and adapter '
            "notes saved to this trip. I'll check the forecast again the morning you fly.",
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.document,
      headline: 'Japan prep bundle sent ✅',
      details: [
        'Kid-friendly etiquette primer for Zoe & Leo',
        'Packing + plug adapter notes saved to trip',
      ],
    ),
    availability: ScenarioAvailability.no,
  ),

  // ---------------------------------------------------------------------
  // Airport
  // ---------------------------------------------------------------------
  const ProactiveScenario(
    id: 'airport-security-wayfinding',
    stage: TripStage.airport,
    useCaseTitle: 'Family-specific security & wayfinding at ATL',
    situation:
        'At the airport with two kids, a stroller and 11 days of luggage, Priya wants the '
        'path of least resistance through security — not just a wait-time number.',
    notificationText: '👨‍👩‍👧‍👦 Family security lane is open at Checkpoint C, a 5-minute walk — '
        'usually faster with strollers and kids.',
    turns: [
      ScenarioTurn(
        parentLine: 'Do we need to do anything differently with the kids?',
        matchKeywords: ['do anything differently', 'with the kids'],
        conciergeReply:
            'Leo and Zoe can keep their shoes on through the family lane, and you won\'t '
            "need to remove the stroller's parts — just fold it at the belt. I'll route you "
            'there now.',
      ),
      ScenarioTurn(
        parentLine: 'What happens to the stroller after that?',
        matchKeywords: ['stroller after', 'what happens to the stroller'],
        conciergeReply:
            "You'll wheel it right to the gate and gate-check it there — no need to check it "
            'at the counter. I\'ve already got the tag ready from check-in.',
      ),
      ScenarioTurn(
        parentLine: 'Perfect, take us there.',
        matchKeywords: ['take us there', 'guide us'],
        conciergeReply:
            'Guiding you to the family lane at Checkpoint C now — about 5 minutes, and I\'ll '
            'remind you about stroller gate-check when you reach Gate 22.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.family,
      headline: 'Routing to the family lane — Checkpoint C ✅',
      details: [
        '~5 minute walk',
        'Stroller gate-check reminder set for Gate 22',
      ],
    ),
    availability: ScenarioAvailability.partial,
  ),
  const ProactiveScenario(
    id: 'airport-dfw-layover',
    stage: TripStage.airport,
    useCaseTitle: 'Proactive DFW layover recommendation for kids',
    situation:
        'With the longer connection booked, the family has 2h 10m at DFW with two hungry, '
        "restless kids before an 11-hour flight. AA's app doesn't proactively suggest "
        'anything for a layover.',
    notificationText: "🧸 You've got 2h 10m at DFW. Terminal D has a kids' play area 3 minutes "
        'from your gate, and a family-friendly restaurant right next to it.',
    turns: [
      ScenarioTurn(
        parentLine: 'Is there anything Leo will actually eat? He\'s picky.',
        matchKeywords: ['leo eat', 'picky'],
        conciergeReply:
            "The restaurant by the play area has a straightforward kids' menu — chicken "
            "tenders, mac and cheese. There's also a sit-down spot two gates further if "
            "you'd rather not rush.",
      ),
      ScenarioTurn(
        parentLine: "The play area sounds perfect, let's do that.",
        matchKeywords: ['play area', "let's do that"],
        conciergeReply:
            'Guiding you there now — 3 minutes from your gate. I\'ll alert you with enough '
            'time to get back for boarding, factoring in the walk with the kids and '
            'stroller.',
      ),
      ScenarioTurn(
        parentLine: 'Thanks — one less thing to figure out.',
        matchKeywords: ['thanks', 'one less thing'],
        conciergeReply:
            "Anytime. I'll ping you about 40 minutes before boarding so there's no rush "
            'getting back.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.clock,
      headline: 'Guiding you to the DFW play area ✅',
      details: [
        "Kids' menu (chicken tenders / mac & cheese) next door",
        'Boarding reminder set for ~40 minutes before departure',
      ],
    ),
    availability: ScenarioAvailability.no,
  ),

  // ---------------------------------------------------------------------
  // In-Flight
  // ---------------------------------------------------------------------
  const ProactiveScenario(
    id: 'inflight-comfort-setup',
    stage: TripStage.inFlight,
    useCaseTitle: 'Proactive comfort & entertainment setup for kids (DFW–NRT)',
    situation:
        "On the 11-hour DFW–Narita leg, Leo gets restless and has mild motion sensitivity; "
        "Zoe wants Wi-Fi to message friends. AA's app doesn't personalize the in-flight "
        'experience per passenger.',
    notificationText: "🎬 Long flight ahead — I've queued kid-friendly movies on Leo's seatback "
        'and free messaging Wi-Fi for Zoe. Want to swap Leo to the window for the Pacific '
        'coastline view as we climb?',
    turns: [
      ScenarioTurn(
        parentLine: 'Yes to the window swap — and any tips for his motion sensitivity?',
        matchKeywords: ['window swap', 'motion sensitivity'],
        conciergeReply:
            'Swapped Leo to 34A, window ✅ An aisle-adjacent seat with a horizon view usually '
            "helps more than a fully blocked window — I've also flagged his meal for a "
            'lighter option, which tends to sit better on long flights.',
      ),
      ScenarioTurn(
        parentLine: 'Can Zoe message us if she\'s seated separately?',
        matchKeywords: ['zoe message', 'seated separately'],
        conciergeReply:
            "She's actually seated right next to Leo, but yes — free messaging Wi-Fi is "
            'active for the whole family.',
      ),
      ScenarioTurn(
        parentLine: 'Great, thank you.',
        matchKeywords: ['thank you', 'thanks'],
        conciergeReply:
            "You're welcome — I'll check in again a couple of hours before landing to help "
            'prep for Narita immigration with the kids.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.seat,
      headline: 'Leo swapped to 34A, window ✅',
      details: [
        'Lighter meal flagged for motion sensitivity',
        'Free messaging Wi-Fi active for the whole family',
      ],
    ),
    availability: ScenarioAvailability.no,
  ),
  const ProactiveScenario(
    id: 'inflight-arrival-prep',
    stage: TripStage.inFlight,
    useCaseTitle: 'Proactive arrival & customs prep, mid-flight',
    situation:
        "Two hours from Narita, the Bennetts are nervous about navigating immigration with "
        "two kids and meeting Priya's parents in a foreign arrivals hall. AA's app gives "
        'flight status but no arrival prep.',
    notificationText: "🛩 Landing in 2 hours. Since you're traveling with minors, here's the "
        "family immigration lane at Narita — and I've pre-filled your customs forms.",
    turns: [
      ScenarioTurn(
        parentLine: 'Do the kids need their own customs forms?',
        matchKeywords: ['kids customs forms', 'own customs forms'],
        conciergeReply:
            "One form per family is fine for a visit like this — I've pre-filled it with "
            "your details; you'll just need to sign before you land. I'll have it ready on "
            'your screen.',
      ),
      ScenarioTurn(
        parentLine: "Where do we meet Priya's parents after we land?",
        matchKeywords: ["priya's parents", 'meet after we land'],
        conciergeReply:
            'The public arrivals area just past customs has a clearly marked meeting point — '
            "I'll guide you there, and I can send Priya's parents an update on your landing "
            'time.',
      ),
      ScenarioTurn(
        parentLine: 'Yes, send them an update.',
        matchKeywords: ['send them an update', 'send update'],
        conciergeReply:
            "Done ✅ I've sent your landing time, and I'll guide your family to the meeting "
            'point after customs. Almost there.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.document,
      headline: 'Customs form pre-filled ✅',
      details: [
        'One family form ready to sign before landing',
        "Landing-time update sent to Priya's parents",
      ],
    ),
    availability: ScenarioAvailability.no,
  ),

  // ---------------------------------------------------------------------
  // Arrival
  // ---------------------------------------------------------------------
  const ProactiveScenario(
    id: 'arrival-baggage-customs',
    stage: TripStage.arrival,
    useCaseTitle: 'Proactive baggage & customs guidance with kids',
    situation:
        'Landed at Narita: four checked bags for an 11-day trip, two tired kids, grandparents '
        "waiting. AA's tracking is reactive and offers nothing at a foreign arrival airport.",
    notificationText: '🧳 Your 4 bags are on Carousel 8. The visitor customs lane is to your '
        'left — usually the shorter line at this hour.',
    turns: [
      ScenarioTurn(
        parentLine: 'Is there somewhere the kids can sit while we wait for bags?',
        matchKeywords: ['kids sit', 'wait for bags'],
        conciergeReply:
            'There\'s bench seating right by Carousel 8, about 20 feet from where the bags '
            'come out — Leo and Zoe can sit while you watch for the bags.',
      ),
      ScenarioTurn(
        parentLine: 'Any issue bringing gifts through customs?',
        matchKeywords: ['gifts through customs', 'customs issue'],
        conciergeReply:
            'For personal gifts within normal quantities, no — nothing beyond the standard '
            "form you already signed. I can flag anything specific if you're unsure.",
      ),
      ScenarioTurn(
        parentLine: "We're okay, thanks.",
        matchKeywords: ["we're okay", 'thanks'],
        conciergeReply:
            "Great — once you've got your bags, the exit to the public arrivals hall is "
            "straight past customs. Priya's parents should be right at the meeting point.",
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.luggage,
      headline: 'Bags on Carousel 8 ✅',
      details: [
        'Bench seating nearby for the kids',
        'Exit to arrivals hall straight past customs',
      ],
    ),
    availability: ScenarioAvailability.no,
  ),
  const ProactiveScenario(
    id: 'arrival-trip-wrapup',
    stage: TripStage.arrival,
    useCaseTitle: 'Proactive trip wrap-up & return-journey nudge',
    situation:
        "The family has made it — bags collected, grandparents found. The concierge closes "
        'the loop and gently sets up the return journey eleven days out, without being '
        'asked.',
    notificationText: '🎉 Welcome to Tokyo! You earned 9,840 AAdvantage miles on this trip. '
        "I'll check in a few days before your April 15th return — enjoy time with family "
        'until then.',
    turns: [
      ScenarioTurn(
        parentLine: 'How many miles do we have now combined?',
        matchKeywords: ['miles combined', 'total miles'],
        conciergeReply:
            "Marcus's account is now at 223,840 miles — enough for another family trip like "
            'this one, or a nice upgrade on a future flight.',
      ),
      ScenarioTurn(
        parentLine: 'Anything we should think about before the flight home?',
        matchKeywords: ['before the flight home', 'flight home'],
        conciergeReply:
            "Nothing yet — I'll reach out three days before departure with check-in, any "
            'weather notes for Atlanta, and a reminder about the DFW connection on the way '
            'back. For now, just enjoy the visit.',
      ),
      ScenarioTurn(
        parentLine: 'Perfect, thank you.',
        matchKeywords: ['perfect, thank you', 'thanks'],
        conciergeReply:
            "Anytime — congratulations on the trip. I'll be here when it's time to head "
            'home.',
      ),
    ],
    concludingAction: ActionSummary(
      icon: ActionIcon.celebration,
      headline: 'Return-trip reminder scheduled ✅',
      details: [
        '223,840 AAdvantage miles total',
        'Check-in set for 3 days before the Apr 15 return flight',
      ],
    ),
    availability: ScenarioAvailability.partial,
  ),
];

/// Looks up a [ProactiveScenario] by [ProactiveScenario.id], or `null` if
/// [scenarioId] doesn't match any catalog entry.
ProactiveScenario? scenarioById(String scenarioId) {
  final index = scenarioCatalog.indexWhere((s) => s.id == scenarioId);
  return index == -1 ? null : scenarioCatalog[index];
}

/// The [ProactiveScenario] immediately after [scenarioId] in catalog order
/// (Inspire → Arrival) — used to point the post-use-case reminder
/// notification at the next moment in the Bennetts' trip. Returns `null` for
/// an unknown id or for the last scenario, since the trip is over by then.
ProactiveScenario? nextScenarioAfter(String scenarioId) {
  final index = scenarioCatalog.indexWhere((s) => s.id == scenarioId);
  if (index == -1 || index + 1 >= scenarioCatalog.length) return null;
  return scenarioCatalog[index + 1];
}
