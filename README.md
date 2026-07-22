# AI Travel Assistant — Flutter Feature Module

A self-contained, plug-in AI Travel Assistant for airline mobile apps. Passengers
interact via text or voice inside a single chat surface to check flight status,
change seats, buy baggage, get terminal/gate/boarding info, navigate the airport,
or escalate to a human agent — all without leaving the conversation.

## Architecture

- **Clean Architecture** (presentation → domain → data), **Feature-First** module
  layout so this can be copied into a host app as one folder.
- **MVVM** in the presentation layer: Views (pages/widgets) are dumb; ViewModels
  hold state and call use cases.
- **Repository Pattern** in domain (interfaces) + data (implementations), so the
  AI provider and backend APIs are swappable (OpenAI today, provider-agnostic
  interface for tomorrow).
- **Riverpod** for DI + state management (code-generated providers).
- **Dio** for networking, **Freezed/json_serializable** for immutable models,
  **Hive/SharedPreferences** for local persistence (chat history, draft state).

## Folder Structure

```
lib/
  core/
    di/providers.dart            # full Riverpod wiring, mock/real backend toggle
    errors/                      # Failure hierarchy + data-layer exceptions
    theme/app_theme.dart         # light/dark ThemeData
    utils/                       # Result<T>, safeCall
  features/
    ai_travel_assistant/
      presentation/
        pages/chat_page.dart
        widgets/
          chat_bubble.dart, typing_indicator.dart, suggested_prompts.dart,
          message_composer.dart, markdown_message.dart, rich_card_widget.dart
          seat_map/               # SeatMapCard, SeatTile
          baggage/                # BaggageOptionsCard, BaggageSuccessCard
          flight/                 # FlightStatusCard
          airport/                # AirportInfoCard
        viewmodels/               # ChatState, ChatViewModel
      domain/
        entities/                # ChatMessage, Flight, Seat, BaggageOption, Intent...
        repositories/             # abstract interfaces
        usecases/                 # SendMessage, GetFlightStatus, ChangeSeat, ...
      data/
        datasource/                # remote (Dio + Mock) + local (Hive) data sources
        models/                    # DTOs (Freezed + json_serializable)
        repositories/               # concrete implementations of domain interfaces
      services/
        voice_service.dart         # speech_to_text + flutter_tts wrapper
        mock_backend/mock_backend_server.dart  # stateful mock + error injection
      routes/                      # feature-local navigation entry point
  main.dart                        # standalone demo runner
test/
  unit/                            # use case + ChatViewModel tests
  widget/                          # ChatBubble, SeatMapCard tests
  repository/                      # repository implementation tests
  mocks/                           # shared mocktail mocks
docs/
  ARCHITECTURE.md, SEQUENCE_DIAGRAMS.md, CLASS_DIAGRAM.md,
  API_CONTRACTS.md, SETUP_GUIDE.md
```

## Integration into a host app

1. Copy `lib/features/ai_travel_assistant` (and `lib/core` pieces you don't
   already have) into the host app.
2. Merge `pubspec.yaml` dependencies into the host app's `pubspec.yaml`.
3. Register the feature's providers/DI in the host app's composition root.
4. Push `AiTravelAssistantEntryPoint` (defined in `routes/`) from wherever the
   host app wants to expose the assistant (e.g. a floating action button or a
   tab).

## Delivery Plan — all phases complete

- [x] 1. Project structure
- [x] 2. Domain layer (entities, repository interfaces, use cases)
- [x] 3. Data layer (models, data sources)
- [x] 4. Repository implementations
- [x] 5. Use cases (wiring — see `lib/core/di/providers.dart`)
- [x] 6. ViewModels (`ChatState` + `ChatViewModel`)
- [x] 7. Chat UI (`ChatPage` + bubble/composer/typing/rich-card dispatcher)
- [x] 8. Seat selection UI (`SeatMapCard` + `SeatTile`)
- [x] 9. Baggage purchase UI (`BaggageOptionsCard` + `BaggageSuccessCard`)
- [x] 10. Flight information cards (`FlightStatusCard` + `AirportInfoCard`)
- [x] 11. Voice assistant integration (`VoiceService`: speech_to_text + flutter_tts)
- [x] 12. Mock backend (`MockBackendServer` — stateful, with error injection)
- [x] 13. Unit tests (unit/widget/repository/mocks)
- [x] 14. Documentation (`docs/` — architecture, sequence & class diagrams, API contracts, setup guide)

### What's runnable right now

The module runs standalone, end-to-end, against the in-memory mock backend:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates *.freezed.dart / *.g.dart
flutter run -t lib/main.dart
```

Try: *"Is my flight delayed?"* → interactive `FlightStatusCard`. *"I want a
window seat"* → tap a seat on `SeatMapCard`, confirm, get a real
seat-change confirmation. *"I need another 10kg of baggage"* → tap **Add**
on `BaggageOptionsCard`, get a `BaggageSuccessCard` with a confirmation
code. *"Which terminal do I go to?"* → `AirportInfoCard` with walking
directions. Tap the mic to speak instead of typing; assistant text replies
are read back via TTS (toggle with `ChatViewModel.toggleVoiceOutput()`).
Chat history persists across restarts via Hive.

To see the error-handling paths, flip a flag on
`MockBackendServer.instance` (see `docs/SETUP_GUIDE.md` §5) — e.g.
`simulateSeatUnavailable = true` before confirming a seat produces a real
"That seat is no longer available." error message inline in the chat.

### Documentation

- `docs/ARCHITECTURE.md` — layer responsibilities + component diagram
- `docs/SEQUENCE_DIAGRAMS.md` — seat selection, baggage purchase (with a
  simulated payment failure), and low-confidence escalation flows
- `docs/CLASS_DIAGRAM.md` — domain entity relationships + failure hierarchy
- `docs/API_CONTRACTS.md` — exact request/response JSON for every endpoint,
  so a real backend team can implement against it directly
- `docs/SETUP_GUIDE.md` — codegen, host-app integration, mock→real backend
  switch-over, voice permissions, running the tests

### Testing

```bash
flutter test
```

`test/unit/` (use cases + `ChatViewModel` intent routing), `test/repository/`
(model→entity and exception→`Failure` mapping), and `test/widget/`
(`ChatBubble`, `SeatMapCard`) — all using mocktail doubles from
`test/mocks/mocks.dart`. See `docs/SETUP_GUIDE.md` §7 for notes on testing
around voice and Hive.
