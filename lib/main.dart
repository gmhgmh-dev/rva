import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';
import 'services/driving_assistant_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark navigation bar and status bar for optimal in-car contrast
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121418),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final assistantManager = DrivingAssistantManager();
  try {
    await assistantManager.init(loadAsset: true);
  } catch (e, stack) {
    debugPrint('Fatal initialization error caught in main: $e\n$stack');
  }

  runApp(RoadsVoiceAssistantApp(assistantManager: assistantManager));
}

class RoadsVoiceAssistantApp extends StatelessWidget {
  final DrivingAssistantManager assistantManager;

  const RoadsVoiceAssistantApp({
    super.key,
    required this.assistantManager,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roads Voice Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1976D2),
          secondary: Color(0xFF00E676),
          surface: Color(0xFF1E222B),
        ),
        scaffoldBackgroundColor: const Color(0xFF121418),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: DashboardScreen(assistantManager: assistantManager),
    );
  }
}

typedef VentspilsVoiceAssistantApp = RoadsVoiceAssistantApp;
