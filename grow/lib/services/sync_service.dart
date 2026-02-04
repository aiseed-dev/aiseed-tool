import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'photo_service.dart';

/// 同期モード
enum SyncMode {
  local,      // ローカルのみ（同期なし）
  cloudflare, // Cloudflare Workers + R2 + D1
}

const kSyncModePref = 'sync_mode';
const kLastSyncPref = 'last_sync_timestamp';

/// サーバーとのデータ同期を管理するサービス
class SyncService {
  final DatabaseService _db;
  final String _serverUrl;
  final String _serverToken;

  SyncService({
    required DatabaseService db,
    required String serverUrl,
    required String serverToken,
  })  : _db = db,
        _serverUrl = serverUrl.endsWith('/')
            ? serverUrl.substring(0, serverUrl.length - 1)
            : serverUrl,
        _serverToken = serverToken;

  static const _syncTables = [
    'locations',
    'plots',
    'crops',
    'records',
    'record_photos',
    'observations',
    'observation_entries',
  ];

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_serverToken',
        'Content-Type': 'application/json',
      };

  /// 同期を実行（pull → push の順）
  Future<SyncResult> sync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString(kLastSyncPref) ?? '1970-01-01T00:00:00.000Z';

    // 1. Pull: サーバーから更新を取得
    final pullResult = await _pull(lastSync);

    // 2. Push: ローカルの更新を送信
    final pushResult = await _push(lastSync);

    // 3. 写真の同期
    final photoResult = await _syncPhotos();

    // 4. タイムスタンプを更新
    final newTimestamp = pullResult.timestamp ?? pushResult.timestamp ?? DateTime.now().toUtc().toIso8601String();
    await prefs.setString(kLastSyncPref, newTimestamp);

    return SyncResult(
      pulled: pullResult.count,
      pushed: pushResult.count,
      photosUploaded: photoResult,
    );
  }

  Future<_PullResult> _pull(String since) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/sync/pull'),
      headers: _headers,
      body: jsonEncode({'since': since}),
    );

    if (response.statusCode != 200) {
      throw SyncException('Pull failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    var count = 0;

    // Apply updates from server
    for (final table in _syncTables) {
      final rows = data[table] as List<dynamic>? ?? [];
      for (final row in rows) {
        await _db.upsertRow(table, Map<String, dynamic>.from(row as Map));
        count++;
      }
    }

    // Apply deletions
    final deleted = data['deleted'] as List<dynamic>? ?? [];
    for (final del in deleted) {
      final map = del as Map<String, dynamic>;
      final tableName = map['table_name'] as String;
      if (_syncTables.contains(tableName)) {
        await _db.applyDeletion(tableName, map['id'] as String);
        count++;
      }
    }

    return _PullResult(
      count: count,
      timestamp: data['timestamp'] as String?,
    );
  }

  Future<_PushResult> _push(String since) async {
    final body = <String, dynamic>{};
    var count = 0;

    // Gather local changes
    for (final table in _syncTables) {
      final rows = await _db.getUpdatedRows(table, since);
      if (rows.isNotEmpty) {
        body[table] = rows;
        count += rows.length;
      }
    }

    // Gather deletions
    final deleted = await _db.getDeletedRecords(since);
    if (deleted.isNotEmpty) {
      body['deleted'] = deleted.map((d) => {
            'id': d['id'],
            'table_name': d['table_name'],
          }).toList();
      count += deleted.length;
    }

    if (count == 0) return _PushResult(count: 0, timestamp: null);

    final response = await http.post(
      Uri.parse('$_serverUrl/sync/push'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw SyncException('Push failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return _PushResult(
      count: count,
      timestamp: data['timestamp'] as String?,
    );
  }

  /// 未同期の写真を R2 にアップロード
  Future<int> _syncPhotos() async {
    final rows = await _db.getUpdatedRows('record_photos', '1970-01-01T00:00:00.000Z');
    var uploaded = 0;

    for (final row in rows) {
      // Skip if already uploaded
      if (row['r2_key'] != null) continue;

      final filePath = row['file_path'] as String;
      final file = File(filePath);
      if (!file.existsSync()) continue;

      // Upload to server
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_serverUrl/photos'),
      );
      request.headers['Authorization'] = 'Bearer $_serverToken';
      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final response = await request.send();
      if (response.statusCode != 200) continue;

      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final r2Key = data['key'] as String?;

      if (r2Key != null) {
        // Update local record with r2_key
        await _db.upsertRow('record_photos', {
          ...row,
          'r2_key': r2Key,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        uploaded++;
      }
    }

    return uploaded;
  }
}

class SyncResult {
  final int pulled;
  final int pushed;
  final int photosUploaded;

  const SyncResult({
    required this.pulled,
    required this.pushed,
    required this.photosUploaded,
  });
}

class SyncException implements Exception {
  final String message;
  const SyncException(this.message);
  @override
  String toString() => 'SyncException: $message';
}

class _PullResult {
  final int count;
  final String? timestamp;
  const _PullResult({required this.count, required this.timestamp});
}

class _PushResult {
  final int count;
  final String? timestamp;
  const _PushResult({required this.count, required this.timestamp});
}
