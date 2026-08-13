import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/core/navigation/app_navigator_key.dart';
import 'package:ai_travel_assistant/core/services/local_notification_service.dart';
import 'package:ai_travel_assistant/core/services/shared_preferences_provider.dart';
import 'package:ai_travel_assistant/core/theme/app_theme.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/chat_local_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/routes/ai_travel_assistant_routes.dart';
import 'package:ai_travel_assistant/features/landing/presentation/pages/landing_page.dart';

/// Standalone runner for local development of this module in isolation from
/// a host app. Host apps should instead merge `core/di/providers.dart`'s
/// overrides into their own composition root and push
/// `AiTravelAssistantEntryPoint.route()` from wherever makes sense for them.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await dotenv.load(fileName: '.env', isOptional: true);
  await Hive.initFlutter();
  final chatHistoryBox = await Hive.openBox<Map<dynamic, dynamic>>(
    HiveChatLocalDataSource.boxName,
  );
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        chatHistoryBoxProvider.overrideWithValue(chatHistoryBox),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const AiTravelAssistantDemoApp(),
    ),
  );
}

class AiTravelAssistantDemoApp extends ConsumerStatefulWidget {
  const AiTravelAssistantDemoApp({super.key});

  @override
  ConsumerState<AiTravelAssistantDemoApp> createState() => _AiTravelAssistantDemoAppState();
}

class _AiTravelAssistantDemoAppState extends ConsumerState<AiTravelAssistantDemoApp> {
  @override
  void initState() {
    super.initState();
    // Tapping the post-use-case reminder notification has no BuildContext of
    // its own, so it routes through the shared `rootNavigatorKey` instead.
    ref.read(localNotificationServiceProvider).onScenarioTapped = (payload) {
      // A `live:` payload carries the backend's own push copy, which opens
      // the conversation as-is. Anything else names a scripted scenario from
      // the concierge catalogue — the original behaviour, untouched.
      const prefix = LocalNotificationService.liveMomentPayloadPrefix;
      final isLive = payload.startsWith(prefix);
      rootNavigatorKey.currentState?.push(
        AiTravelAssistantEntryPoint.route(
          autoStartScenarioId: isLive ? null : payload,
          openingLine: isLive ? payload.substring(prefix.length) : null,
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'AI Travel Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const LandingPage(),
    );
  }
}
