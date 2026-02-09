import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

/// Client for the Grow GPU Server API.
class GpuServerService {
  final SettingsService settings;

  GpuServerService({required this.settings});

  String get _baseUrl => settings.serverUrl;
  bool get isConfigured => _baseUrl.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (settings.serverToken.isNotEmpty)
          'Authorization': 'Bearer ${settings.serverToken}',
      };

  // ---------- Weather (WS90 / Ecowitt) ----------

  Future<Map<String, dynamic>?> getWeatherLatest() async {
    if (!isConfigured) return null;
    final resp = await http.get(
      Uri.parse('$_baseUrl/weather/latest'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return null;
    return jsonDecode(resp.body);
  }

  Future<List<dynamic>> getWeatherHistory({int hours = 24}) async {
    if (!isConfigured) return [];
    final resp = await http.get(
      Uri.parse('$_baseUrl/weather/history?hours=$hours&limit=200'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return [];
    return jsonDecode(resp.body) as List;
  }

  Future<Map<String, dynamic>?> getWeatherSummary({int hours = 24}) async {
    if (!isConfigured) return null;
    final resp = await http.get(
      Uri.parse('$_baseUrl/weather/summary?hours=$hours'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return null;
    return jsonDecode(resp.body);
  }

  // ---------- AMeDAS ----------

  Future<List<dynamic>> searchAmedasStations(String query) async {
    if (!isConfigured) return [];
    final resp = await http.get(
      Uri.parse('$_baseUrl/amedas/stations?q=${Uri.encodeComponent(query)}'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return [];
    return jsonDecode(resp.body) as List;
  }

  Future<Map<String, dynamic>?> getAmedasLatest(String stationId) async {
    if (!isConfigured) return null;
    final resp = await http.get(
      Uri.parse('$_baseUrl/amedas/data/latest?station_id=$stationId'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return null;
    return jsonDecode(resp.body);
  }

  Future<List<dynamic>> getAmedasHistory(String stationId,
      {int hours = 24}) async {
    if (!isConfigured) return [];
    final resp = await http.get(
      Uri.parse(
          '$_baseUrl/amedas/data/history?station_id=$stationId&hours=$hours'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return [];
    return jsonDecode(resp.body) as List;
  }

  Future<Map<String, dynamic>?> getAmedasSummary(String stationId,
      {String date = ''}) async {
    if (!isConfigured) return null;
    var url = '$_baseUrl/amedas/data/summary?station_id=$stationId';
    if (date.isNotEmpty) url += '&date=$date';
    final resp = await http.get(Uri.parse(url), headers: _headers);
    if (resp.statusCode != 200) return null;
    return jsonDecode(resp.body);
  }

  Future<void> fetchAmedasData(String stationId, {String date = ''}) async {
    if (!isConfigured) return;
    var url = '$_baseUrl/amedas/fetch?station_id=$stationId';
    if (date.isNotEmpty) url += '&date=$date';
    await http.post(Uri.parse(url), headers: _headers);
  }

  // ---------- ECMWF Forecast ----------

  Future<Map<String, dynamic>?> getForecast(double lat, double lon,
      {int days = 7}) async {
    if (!isConfigured) return null;
    final resp = await http.get(
      Uri.parse('$_baseUrl/forecast/ecmwf?lat=$lat&lon=$lon&days=$days'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return null;
    return jsonDecode(resp.body);
  }

  Future<List<dynamic>> getDailyForecast(double lat, double lon,
      {int days = 7}) async {
    if (!isConfigured) return [];
    final resp = await http.get(
      Uri.parse('$_baseUrl/forecast/daily?lat=$lat&lon=$lon&days=$days'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return [];
    return jsonDecode(resp.body) as List;
  }

  Future<List<dynamic>> getSoilForecast(double lat, double lon,
      {int days = 3}) async {
    if (!isConfigured) return [];
    final resp = await http.get(
      Uri.parse('$_baseUrl/forecast/soil?lat=$lat&lon=$lon&days=$days'),
      headers: _headers,
    );
    if (resp.statusCode != 200) return [];
    return jsonDecode(resp.body) as List;
  }
}
