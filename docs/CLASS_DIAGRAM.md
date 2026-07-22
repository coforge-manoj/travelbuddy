# Class Diagram — Domain Entities

```mermaid
classDiagram
    class ChatMessage {
        +String id
        +ChatRole role
        +ChatMessageType type
        +DateTime timestamp
        +String text
        +Object? payload
        +bool isStreaming
    }
    class ChatRole {
        <<enum>>
        user
        assistant
        system
    }
    class ChatMessageType {
        <<enum>>
        text
        flightStatusCard
        seatMapCard
        baggageOptionsCard
        baggageSuccessCard
        airportInfoCard
        agentEscalationCard
        error
    }
    ChatMessage --> ChatRole
    ChatMessage --> ChatMessageType

    class IntentResult {
        +IntentType type
        +double confidence
        +Map~String,String~ entities
        +bool isLowConfidence
    }
    class IntentType {
        <<enum>>
        flightStatus
        seatSelection
        addBaggage
        terminalInformation
        counterInformation
        boardingTime
        airportNavigation
        baggageAllowance
        humanAgent
        faq
        unknown
    }
    IntentResult --> IntentType

    class Flight {
        +String flightNumber
        +String origin
        +String destination
        +FlightStatus status
        +DateTime scheduledDeparture
        +DateTime? estimatedDeparture
        +String? gate
        +String? terminal
        +String? checkInCounter
        +DateTime? boardingTime
    }
    class FlightStatus {
        <<enum>>
        scheduled
        boarding
        delayed
        departed
        cancelled
        landed
        unknown
    }
    Flight --> FlightStatus

    class Booking {
        +String pnr
        +String passengerName
        +Flight flight
    }
    Booking --> Flight

    class Seat {
        +String seatNumber
        +int row
        +String column
        +SeatType type
        +SeatAvailability availability
        +num priceDelta
        +bool isExitRow
        +bool isAvailable
    }
    class SeatType {
        <<enum>>
        window
        middle
        aisle
    }
    class SeatAvailability {
        <<enum>>
        available
        occupied
        selected
        blocked
    }
    Seat --> SeatType
    Seat --> SeatAvailability

    class SeatMap {
        +String flightNumber
        +int rows
        +List~Seat~ seats
        +String currency
    }
    SeatMap --> "many" Seat

    class BaggageOption {
        +String id
        +num extraWeightKg
        +num price
        +String currency
    }
    class BaggageAllowance {
        +num checkedKg
        +num cabinKg
    }
    class BaggagePurchase {
        +String id
        +BaggageOption option
        +BaggagePurchaseStatus status
        +String? confirmationCode
    }
    class BaggagePurchaseStatus {
        <<enum>>
        pending
        success
        failed
    }
    BaggagePurchase --> BaggageOption
    BaggagePurchase --> BaggagePurchaseStatus

    class AirportInfo {
        +String terminal
        +String checkInCounter
        +String gate
        +int walkingTimeMinutes
        +String? indoorMapAssetPath
        +List~String~ directions
    }

    class EscalationRequest {
        +String reason
        +String conversationSummary
        +double? confidence
    }
    class EscalationResult {
        +int queuePosition
        +int estimatedWaitMinutes
    }
```

## Failure hierarchy

```mermaid
classDiagram
    class Failure {
        <<abstract>>
        +String message
        +String? code
    }
    Failure <|-- NetworkFailure
    Failure <|-- ServerFailure
    Failure <|-- TimeoutFailure
    Failure <|-- SeatUnavailableFailure
    Failure <|-- InvalidBookingFailure
    Failure <|-- PaymentFailure
    Failure <|-- AiTimeoutFailure
    Failure <|-- VoiceRecognitionFailure
    Failure <|-- UnknownFailure
```

`Result<T>` (`Success<T>` / `ResultFailure<T>`) wraps either a value or a
`Failure`; `safeCall` is the single place data-layer exceptions
(`DioException`, `SeatUnavailableException`, `PaymentDeclinedException`,
`AiTimeoutException`, `InvalidBookingException`) get mapped onto this
hierarchy — see `lib/core/utils/safe_call.dart`.
