import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyApiKey = 'anthropic_api_key';
  static const String _keyModel = 'claude_model';
  static const String _keyServerUrl = 'server_url';
  static const String _keyServerToken = 'server_token';
  static const String _keySystemPrompt = 'default_system_prompt';

  static const String defaultSystemPrompt = '''あなたは栽培のコワーカーです。
ユーザーと一緒に菜園の栽培計画を考え、栽培の記録を手伝います。
日本語で回答してください。''';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get apiKey => _prefs.getString(_keyApiKey) ?? '';
  Future<void> setApiKey(String value) =>
      _prefs.setString(_keyApiKey, value);

  String get model =>
      _prefs.getString(_keyModel) ?? 'claude-sonnet-4-5-20250929';
  Future<void> setModel(String value) =>
      _prefs.setString(_keyModel, value);

  String get serverUrl => _prefs.getString(_keyServerUrl) ?? '';
  Future<void> setServerUrl(String value) =>
      _prefs.setString(_keyServerUrl, value);

  String get serverToken => _prefs.getString(_keyServerToken) ?? '';
  Future<void> setServerToken(String value) =>
      _prefs.setString(_keyServerToken, value);

  String get systemPrompt =>
      _prefs.getString(_keySystemPrompt) ?? defaultSystemPrompt;
  Future<void> setSystemPrompt(String value) =>
      _prefs.setString(_keySystemPrompt, value);

  bool get isApiConfigured => apiKey.isNotEmpty;
  bool get isServerConfigured => serverUrl.isNotEmpty;
}
