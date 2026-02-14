import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'services/conversation_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  await settings.init();

  final conversationService = ConversationService();
  await conversationService.init();

  runApp(GrowCoworkApp(
    settings: settings,
    conversationService: conversationService,
  ));
}

class GrowCoworkApp extends StatefulWidget {
  final SettingsService settings;
  final ConversationService conversationService;

  const GrowCoworkApp({
    super.key,
    required this.settings,
    required this.conversationService,
  });

  @override
  State<GrowCoworkApp> createState() => _GrowCoworkAppState();
}

class _GrowCoworkAppState extends State<GrowCoworkApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grow Cowork',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        settings: widget.settings,
        conversationService: widget.conversationService,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}
