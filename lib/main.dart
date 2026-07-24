import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ai_travel_assistant/core/config/app_env.dart';
import 'package:ai_travel_assistant/core/di/providers.dart';
import 'package:ai_travel_assistant/core/theme/app_theme.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/data/datasource/chat_local_datasource.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/presentation/pages/chat_page.dart';

/// Standalone runner for local development of this module in isolation from
/// a host app. Host apps should instead merge `core/di/providers.dart`'s
/// overrides into their own composition root and push
/// `AiTravelAssistantEntryPoint.route()` from wherever makes sense for them.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.ensureLoaded();
  await Hive.initFlutter();
  final chatHistoryBox = await Hive.openBox<Map<dynamic, dynamic>>(
    HiveChatLocalDataSource.boxName,
  );

  runApp(
    ProviderScope(
      overrides: [
        chatHistoryBoxProvider.overrideWithValue(chatHistoryBox),
      ],
      child: const AiTravelAssistantDemoApp(),
    ),
  );
}

class AiTravelAssistantDemoApp extends StatelessWidget {
  const AiTravelAssistantDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Travel Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const ChatPage(),
    );
  }
}
