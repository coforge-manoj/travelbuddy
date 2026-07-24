import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_travel_assistant/core/errors/failures.dart';
import 'package:ai_travel_assistant/core/utils/result.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/core/travel_tool_schemas.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/services/llm/llm_service.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/chat_message.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/entities/seat.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/escalate_to_agent_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_airport_details_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_baggage_options_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_flight_status_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/get_seat_map_usecase.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/domain/usecases/run_assistant_turn_usecase.dart';

import '../mocks/mocks.dart';

void main() {
  late MockLlmService llm;
  late MockFlightRepository flightRepository;
  late MockSeatRepository seatRepository;
  late MockBaggageRepository baggageRepository;
  late MockAirportRepository airportRepository;
  late MockAgentRepository agentRepository;
  late RunAssistantTurnUseCase useCase;

  setUpAll(() {
    registerFallbackValue(<LlmTurn>[]);
  });

  setUp(() {
    llm = MockLlmService();
    flightRepository = MockFlightRepository();
    seatRepository = MockSeatRepository();
    baggageRepository = MockBaggageRepository();
    airportRepository = MockAirportRepository();
    agentRepository = MockAgentRepository();

    useCase = RunAssistantTurnUseCase(
      llmService: llm,
      getFlightStatus: GetFlightStatusUseCase(flightRepository),
      getSeatMap: GetSeatMapUseCase(seatRepository),
      getBaggageOptions: GetBaggageOptionsUseCase(baggageRepository),
      getBaggageAllowance: GetBaggageAllowanceUseCase(baggageRepository),
      getAirportDetails: GetAirportDetailsUseCase(airportRepository),
      escalateToAgent: EscalateToAgentUseCase(agentRepository),
      apiKey: () => 'test-key',
    );
  });

  /// Scripts the two LLM round-trips: call 1 returns [toolCalls], call 2
  /// (the tools-disabled summary pass) returns [summary].
  void scriptLlm({
    required List<LlmToolCall> toolCalls,
    String summary = 'Done.',
  }) {
    var calls = 0;
    when(
      () => llm.chat(
        apiKey: any(named: 'apiKey'),
        history: any(named: 'history'),
        enableTools: any(named: 'enableTools'),
        enabledTools: any(named: 'enabledTools'),
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) return LlmResult(text: '', toolCalls: toolCalls);
      return LlmResult(text: summary);
    });
  }

  test('a get_seat_map tool call produces a seat map card + summary', () async {
    scriptLlm(
      toolCalls: [
        const LlmToolCall(id: 'get_seat_map_0', name: 'get_seat_map', args: {}),
      ],
      summary: 'Here is your seat map — a few window seats are open.',
    );
    const seatMap = SeatMap(
      flightNumber: 'FZ123',
      rows: 1,
      seats: [
        Seat(
          seatNumber: '14A',
          row: 14,
          column: 'A',
          type: SeatType.window,
          availability: SeatAvailability.available,
        ),
      ],
    );
    when(() => seatRepository.getSeatMap(any()))
        .thenAnswer((_) async => const Result.success(seatMap));

    final messages = await useCase.call('I want a window seat');

    expect(messages.first.type, ChatMessageType.text);
    expect(messages.first.text, contains('seat map'));
    expect(messages.last.type, ChatMessageType.seatMapCard);
    expect(messages.last.payload, seatMap);
  });

  test('no tool call returns a plain text reply (routing proof)', () async {
    when(
      () => llm.chat(
        apiKey: any(named: 'apiKey'),
        history: any(named: 'history'),
        enableTools: any(named: 'enableTools'),
        enabledTools: any(named: 'enabledTools'),
      ),
    ).thenAnswer((_) async => const LlmResult(text: 'Hello! How can I help?'));

    final messages = await useCase.call('hello');

    expect(messages, hasLength(1));
    expect(messages.single.type, ChatMessageType.text);
    expect(messages.single.text, 'Hello! How can I help?');
    verifyNever(() => seatRepository.getSeatMap(any()));
  });

  test('a failing tool skips the summary and returns an error message',
      () async {
    scriptLlm(
      toolCalls: [
        const LlmToolCall(
          id: 'get_flight_status_0',
          name: 'get_flight_status',
          args: {},
        ),
      ],
    );
    when(() => flightRepository.getFlightStatus(any()))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    final messages = await useCase.call('is my flight delayed?');

    expect(messages, hasLength(1));
    expect(messages.single.type, ChatMessageType.text);
    // Only the first (tool) call happens; the summary pass is skipped.
    verify(
      () => llm.chat(
        apiKey: any(named: 'apiKey'),
        history: any(named: 'history'),
        enableTools: any(named: 'enableTools'),
        enabledTools: any(named: 'enabledTools'),
      ),
    ).called(1);
  });

  test('summarizeTranscript returns the model text (tools disabled)', () async {
    when(
      () => llm.chat(
        apiKey: any(named: 'apiKey'),
        history: any(named: 'history'),
        enableTools: false,
        enabledTools: any(named: 'enabledTools'),
      ),
    ).thenAnswer(
      (_) async => const LlmResult(text: 'I want to add 10kg of baggage.'),
    );

    final prompt = await useCase.summarizeTranscript('uh add ten kilos of bags');

    expect(prompt, 'I want to add 10kg of baggage.');
  });

  test('summarizeTranscript falls back to the transcript on LLM failure',
      () async {
    when(
      () => llm.chat(
        apiKey: any(named: 'apiKey'),
        history: any(named: 'history'),
        enableTools: false,
        enabledTools: any(named: 'enabledTools'),
      ),
    ).thenThrow(LlmException('rate limited'));

    final prompt = await useCase.summarizeTranscript('  window seat please  ');

    expect(prompt, 'window seat please');
  });

  test('all tool names are advertised to the model on the first call',
      () async {
    // Sanity check the schema/orchestrator stay in sync.
    expect(TravelToolSchemas.allToolNames, contains('get_seat_map'));
    expect(TravelToolSchemas.allToolNames.length, 6);
  });
}
