import 'package:flutter/material.dart';
import '../services/gpu_server_service.dart';
import '../services/settings_service.dart';

class WeatherScreen extends StatefulWidget {
  final SettingsService settings;

  const WeatherScreen({super.key, required this.settings});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late GpuServerService _server;
  bool _loading = false;

  // WS90 data
  Map<String, dynamic>? _ws90Latest;
  Map<String, dynamic>? _ws90Summary;

  // AMeDAS data
  String _amedasStationId = '';
  String _amedasStationName = '';
  Map<String, dynamic>? _amedasLatest;
  Map<String, dynamic>? _amedasSummary;

  // ECMWF Forecast
  List<dynamic> _dailyForecast = [];
  List<dynamic> _soilForecast = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _server = GpuServerService(settings: widget.settings);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!_server.isConfigured) return;
    setState(() => _loading = true);

    try {
      // WS90
      final ws90Latest = await _server.getWeatherLatest();
      final ws90Summary = await _server.getWeatherSummary(hours: 24);

      // ECMWF (default Tokyo area, user can change)
      // TODO: use configured location
      final daily = await _server.getDailyForecast(35.68, 139.77, days: 7);
      final soil = await _server.getSoilForecast(35.68, 139.77, days: 3);

      if (mounted) {
        setState(() {
          _ws90Latest = ws90Latest;
          _ws90Summary = ws90Summary;
          _dailyForecast = daily;
          _soilForecast = soil;
        });
      }
    } catch (e) {
      // Ignore network errors silently
    }

    setState(() => _loading = false);
  }

  Future<void> _loadAmedas(String stationId, String stationName) async {
    setState(() {
      _amedasStationId = stationId;
      _amedasStationName = stationName;
      _loading = true;
    });

    try {
      // Trigger fetch first
      await _server.fetchAmedasData(stationId);

      final latest = await _server.getAmedasLatest(stationId);
      final summary = await _server.getAmedasSummary(stationId);

      if (mounted) {
        setState(() {
          _amedasLatest = latest;
          _amedasSummary = summary;
        });
      }
    } catch (e) {
      // Ignore
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_server.isConfigured) {
      return const Center(
        child: Text('サーバーURLを設定してください'),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.thermostat), text: 'WS90'),
            Tab(icon: Icon(Icons.location_city), text: 'アメダス'),
            Tab(icon: Icon(Icons.wb_sunny), text: 'ECMWF予報'),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWs90Tab(),
              _buildAmedasTab(),
              _buildForecastTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- WS90 Tab ----------

  Widget _buildWs90Tab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_ws90Latest != null) ...[
            _buildSectionTitle('現在の観測値 (WS90)'),
            const SizedBox(height: 8),
            _buildDataGrid([
              _dataItem(
                  '気温', _fmt(_ws90Latest!['temp_outdoor_c']), '°C', Icons.thermostat),
              _dataItem(
                  '湿度', _fmt(_ws90Latest!['humidity_outdoor']), '%', Icons.water_drop),
              _dataItem('気圧', _fmt(_ws90Latest!['pressure_rel_hpa']), 'hPa',
                  Icons.speed),
              _dataItem('風速', _fmt(_ws90Latest!['wind_speed_ms']), 'm/s',
                  Icons.air),
              _dataItem('突風', _fmt(_ws90Latest!['wind_gust_ms']), 'm/s',
                  Icons.storm),
              _dataItem('日射', _fmt(_ws90Latest!['solar_radiation']), 'W/m²',
                  Icons.wb_sunny),
              _dataItem(
                  'UV指数', _fmt(_ws90Latest!['uv_index']), '', Icons.brightness_7),
              _dataItem('降水量', _fmt(_ws90Latest!['rain_daily_mm']), 'mm/日',
                  Icons.umbrella),
              _dataItem('室温', _fmt(_ws90Latest!['temp_indoor_c']), '°C',
                  Icons.home),
              _dataItem('室内湿度', _fmt(_ws90Latest!['humidity_indoor']), '%',
                  Icons.home),
            ]),
          ],
          if (_ws90Summary != null) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('24時間サマリー'),
            const SizedBox(height: 8),
            _buildDataGrid([
              _dataItem(
                  '最低気温', _fmt(_ws90Summary!['temp_outdoor_min']), '°C', Icons.arrow_downward),
              _dataItem(
                  '最高気温', _fmt(_ws90Summary!['temp_outdoor_max']), '°C', Icons.arrow_upward),
              _dataItem(
                  '平均気温', _fmt(_ws90Summary!['temp_outdoor_avg']), '°C', Icons.thermostat),
              _dataItem('最大突風', _fmt(_ws90Summary!['wind_gust_max']), 'm/s',
                  Icons.storm),
              _dataItem(
                  '最大日射', _fmt(_ws90Summary!['solar_radiation_max']), 'W/m²', Icons.wb_sunny),
              _dataItem('最大UV', _fmt(_ws90Summary!['uv_index_max']), '',
                  Icons.brightness_7),
            ]),
          ],
          if (_ws90Latest == null && !_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('WS90データがありません'),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- AMeDAS Tab ----------

  Widget _buildAmedasTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('アメダス地点検索'),
        const SizedBox(height: 8),
        _AmedasSearchField(
          server: _server,
          onStationSelected: (id, name) => _loadAmedas(id, name),
        ),
        if (_amedasStationName.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('$_amedasStationName ($_amedasStationId)'),
        ],
        if (_amedasLatest != null) ...[
          const SizedBox(height: 8),
          _buildDataGrid([
            _dataItem(
                '気温', _fmt(_amedasLatest!['temp']), '°C', Icons.thermostat),
            _dataItem(
                '湿度', _fmt(_amedasLatest!['humidity']), '%', Icons.water_drop),
            _dataItem(
                '気圧', _fmt(_amedasLatest!['pressure']), 'hPa', Icons.speed),
            _dataItem(
                '風速', _fmt(_amedasLatest!['wind_speed']), 'm/s', Icons.air),
            _dataItem(
                '風向',
                _amedasLatest!['wind_direction_label'] ?? '',
                '',
                Icons.navigation),
            _dataItem('降水量(1h)', _fmt(_amedasLatest!['precipitation_1h']),
                'mm', Icons.umbrella),
            _dataItem('日照(1h)', _fmt(_amedasLatest!['sun_1h']), 'h',
                Icons.wb_sunny),
          ]),
        ],
        if (_amedasSummary != null) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('日別サマリー'),
          const SizedBox(height: 8),
          _buildDataGrid([
            _dataItem('最低気温', _fmt(_amedasSummary!['temp_min']), '°C',
                Icons.arrow_downward),
            _dataItem('最高気温', _fmt(_amedasSummary!['temp_max']), '°C',
                Icons.arrow_upward),
            _dataItem('平均気温', _fmt(_amedasSummary!['temp_avg']), '°C',
                Icons.thermostat),
            _dataItem('降水量合計', _fmt(_amedasSummary!['precipitation_total']),
                'mm', Icons.umbrella),
            _dataItem('日照合計', _fmt(_amedasSummary!['sun_total']), 'h',
                Icons.wb_sunny),
            _dataItem('最大風速', _fmt(_amedasSummary!['wind_speed_max']),
                'm/s', Icons.air),
          ]),
        ],
      ],
    );
  }

  // ---------- ECMWF Forecast Tab ----------

  Widget _buildForecastTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_dailyForecast.isNotEmpty) ...[
            _buildSectionTitle('ECMWF 7日間予報'),
            const SizedBox(height: 8),
            ..._dailyForecast.map((d) => _buildForecastDayCard(d)),
          ],
          if (_soilForecast.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('地温・土壌水分予報 (3日間)'),
            const SizedBox(height: 8),
            _buildSoilTable(),
          ],
          if (_dailyForecast.isEmpty && !_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('予報データがありません'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForecastDayCard(Map<String, dynamic> day) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day['date'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    day['weather_label'] ?? '',
                    style: TextStyle(fontSize: 12, color: cs.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  _miniStat(Icons.thermostat,
                      '${_fmt(day['temp_min'])}~${_fmt(day['temp_max'])}°C'),
                  _miniStat(Icons.grass,
                      '地温 ${_fmt(day['soil_temp_shallow_avg'])}°C'),
                  _miniStat(Icons.umbrella,
                      '${_fmt(day['precipitation_total'])}mm'),
                  _miniStat(
                      Icons.wb_sunny, '${_fmt(day['sunshine_total_min'])}分'),
                  _miniStat(Icons.air, '${_fmt(day['wind_speed_avg'])}m/s'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilTable() {
    // Show soil data every 6 hours from the hourly forecast
    final filtered = <Map<String, dynamic>>[];
    for (int i = 0; i < _soilForecast.length; i++) {
      final item = _soilForecast[i];
      final time = item['time'] as String? ?? '';
      // Pick 06:00, 12:00, 18:00, 00:00
      if (time.endsWith('T06:00') ||
          time.endsWith('T12:00') ||
          time.endsWith('T18:00') ||
          time.endsWith('T00:00')) {
        filtered.add(Map<String, dynamic>.from(item));
      }
    }
    if (filtered.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        columns: const [
          DataColumn(label: Text('日時')),
          DataColumn(label: Text('気温')),
          DataColumn(label: Text('地温\n0-7cm'), numeric: true),
          DataColumn(label: Text('地温\n7-28cm'), numeric: true),
          DataColumn(label: Text('地温\n28-100cm'), numeric: true),
          DataColumn(label: Text('水分\n0-7cm'), numeric: true),
          DataColumn(label: Text('水分\n7-28cm'), numeric: true),
        ],
        rows: filtered.map((r) {
          final time = (r['time'] as String? ?? '').replaceFirst('T', ' ');
          return DataRow(cells: [
            DataCell(Text(time, style: const TextStyle(fontSize: 12))),
            DataCell(Text('${_fmt(r['temperature_2m'])}°C')),
            DataCell(Text('${_fmt(r['soil_temperature_0_to_7cm'])}°C')),
            DataCell(Text('${_fmt(r['soil_temperature_7_to_28cm'])}°C')),
            DataCell(Text('${_fmt(r['soil_temperature_28_to_100cm'])}°C')),
            DataCell(Text(_fmt(r['soil_moisture_0_to_7cm']))),
            DataCell(Text(_fmt(r['soil_moisture_7_to_28cm']))),
          ]);
        }).toList(),
      ),
    );
  }

  // ---------- Helpers ----------

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildDataGrid(List<Widget> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items,
    );
  }

  Widget _dataItem(String label, String value, String unit, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$value $unit'.trim(),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String text) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 2),
          Flexible(
            child: Text(text,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic value) {
    if (value == null) return '-';
    if (value is double) return value.toStringAsFixed(1);
    return value.toString();
  }
}

// ---------- AMeDAS Station Search ----------

class _AmedasSearchField extends StatefulWidget {
  final GpuServerService server;
  final void Function(String id, String name) onStationSelected;

  const _AmedasSearchField({
    required this.server,
    required this.onStationSelected,
  });

  @override
  State<_AmedasSearchField> createState() => _AmedasSearchFieldState();
}

class _AmedasSearchFieldState extends State<_AmedasSearchField> {
  final _controller = TextEditingController();
  List<dynamic> _results = [];

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    final results = await widget.server.searchAmedasStations(q);
    if (mounted) setState(() => _results = results);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '地点名を入力 (例: 東京, 横浜)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _search,
              icon: const Icon(Icons.search, size: 20),
            ),
          ],
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final s = _results[index];
                return ListTile(
                  dense: true,
                  title: Text('${s['kj_name']} (${s['station_id']})'),
                  subtitle: Text(
                    '${s['en_name']} / 標高${s['alt']}m',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    widget.onStationSelected(
                        s['station_id'], s['kj_name']);
                    setState(() => _results = []);
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
