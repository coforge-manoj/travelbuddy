# Sequence Diagrams

## 1. Book a flight, skipping seat & baggage

Flight options are never shown proactively — they only appear once the
passenger asks to book (or taps the "Book a Flight" quick action). From
there the passenger can skip straight through seat selection and baggage to
a confirmed itinerary; the confirmed booking is then remembered across chat
sessions via `BookingSessionStore`.

```mermaid
sequenceDiagram
    actor User
    participant UI as ChatPage
    participant VM as ChatViewModel
    participant CI as ClassifyIntentUseCase
    participant SF as SearchFlightsUseCase
    participant BF as BookFlightUseCase
    participant Store as BookingSessionStore

    User->>UI: "I want to book a flight"
    UI->>VM: sendMessage(text)
    VM->>CI: call(text)
    CI-->>VM: IntentResult(bookFlight, 0.93)
    VM->>SF: call(origin, destination)
    SF-->>VM: Result.success(List~FlightOffer~)
    VM->>UI: appends flightOffersCard ChatMessage
    UI->>User: renders FlightOffersCard

    User->>UI: taps "Select" on UA482
    UI->>VM: selectFlightOffer("UA482")
    VM->>BF: call(offerId, passengerName)
    BF-->>VM: Result.success(Booking)
    VM->>VM: state.pendingBooking = booking
    VM->>UI: appends seatMapCard ChatMessage

    User->>UI: taps "Skip" on SeatMapCard
    UI->>VM: skipSeatSelection()
    VM->>UI: appends baggageOptionsCard ChatMessage

    User->>UI: taps "Continue without extra baggage"
    UI->>VM: finishBooking()
    VM->>UI: appends bookingConfirmationCard ChatMessage
    VM->>Store: confirmedBooking = booking
    Note over Store: survives this chat session closing —\nread back as `_activeBooking` next time
```

## 2. Seat/baggage request with no booking yet

If the passenger asks for something that requires an active flight (seat,
baggage, status, airport info) before booking one — and no booking is
stored in `BookingSessionStore` either — the assistant says so and offers
to start a booking instead of guessing at a demo flight.

```mermaid
sequenceDiagram
    actor User
    participant UI as ChatPage
    participant VM as ChatViewModel
    participant CI as ClassifyIntentUseCase
    participant SF as SearchFlightsUseCase

    User->>UI: "I need to add extra baggage"
    UI->>VM: sendMessage(text)
    VM->>CI: call(text)
    CI-->>VM: IntentResult(addBaggage, 0.88)
    VM->>VM: _activeBooking is null (no pending or stored booking)
    VM->>UI: appends "You don't have a flight booked yet..." text message
    VM->>SF: call(origin, destination)
    SF-->>VM: Result.success(List~FlightOffer~)
    VM->>UI: appends flightOffersCard ChatMessage
    Note over VM,UI: selecting an offer from here re-enters the normal booking flow (see §1)
```

## 3. Seat selection (returning passenger, already booked)

Assumes `_activeBooking` resolves to a booking already confirmed in a
previous session (via `BookingSessionStore`) rather than one still pending
in the guided flow — this is what a passenger typing "I want a window seat"
in a *new* chat session hits.

```mermaid
sequenceDiagram
    actor User
    participant UI as ChatPage / MessageComposer
    participant VM as ChatViewModel
    participant CI as ClassifyIntentUseCase
    participant GS as GetSeatMapUseCase
    participant CS as ChangeSeatUseCase
    participant Repo as SeatRepository
    participant DS as SeatRemoteDataSource

    User->>UI: "I want a window seat"
    UI->>VM: sendMessage(text)
    VM->>CI: call(text)
    CI-->>VM: IntentResult(seatSelection, 0.92)
    VM->>VM: _activeBooking resolves from BookingSessionStore
    VM->>UI: appends flight-info recap text message
    VM->>GS: call(flightNumber)
    GS->>Repo: getSeatMap(flightNumber)
    Repo->>DS: getSeatMap(flightNumber)
    DS-->>Repo: SeatMapModel
    Repo-->>GS: Result.success(SeatMap)
    GS-->>VM: Result.success(SeatMap)
    VM->>UI: appends seatMapCard ChatMessage
    UI->>User: renders SeatMapCard

    User->>UI: taps seat 14A, taps Confirm
    UI->>VM: confirmSeatChange("14A")
    VM->>CS: call(pnr, flightNumber, "14A")
    CS->>Repo: changeSeat(...)
    Repo->>DS: changeSeat(...)
    DS-->>Repo: SeatModel(availability: selected)
    Repo-->>CS: Result.success(Seat)
    CS-->>VM: Result.success(Seat)
    VM->>UI: appends "You are all set in seat 14A" text message
    Note over VM: pendingBooking is null here (not the guided flow),\nso this does NOT chain into baggage options
```

## 4. Baggage purchase (with a simulated payment failure)

```mermaid
sequenceDiagram
    actor User
    participant UI as ChatPage
    participant VM as ChatViewModel
    participant PB as PurchaseBaggageUseCase
    participant Repo as BaggageRepository
    participant DS as BaggageRemoteDataSource
    participant Server as MockBackendServer

    User->>UI: taps "Add" on the 10kg option
    UI->>VM: confirmBaggagePurchase("bag_10kg")
    VM->>PB: call(pnr, "bag_10kg")
    PB->>Repo: purchaseBaggage(...)
    Repo->>DS: purchaseBaggage(...)
    DS->>Server: purchaseBaggage(...)
    Server-->>DS: null  (simulatePaymentFailure = true)
    DS-->>Repo: throw PaymentDeclinedException
    Repo->>Repo: safeCall catches it → PaymentFailure
    Repo-->>PB: Result.failure(PaymentFailure)
    PB-->>VM: Result.failure(PaymentFailure)
    VM->>UI: appends error ChatMessage("Payment could not be processed.")
```

## 5. Low-confidence intent → human escalation offer

```mermaid
sequenceDiagram
    actor User
    participant VM as ChatViewModel
    participant CI as ClassifyIntentUseCase

    User->>VM: sendMessage("uhh something about my thing")
    VM->>CI: call(text)
    CI-->>VM: IntentResult(seatSelection, confidence: 0.1)
    Note over VM: confidence < 0.45 (IntentResult.lowConfidenceThreshold)
    VM->>VM: _appendEscalationOffer()
    VM-->>User: "Would you like to chat with a customer support agent?"
```
