import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/location.dart';

class LocationService {
  /// 現在地を取得。権限がなければリクエストする。
  Future<Position?> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// 場所一覧から現在地に最も近い場所を返す（閾値内）
  /// maxDistanceMeters 以内の場所がなければ null
  Location? findNearest(
    List<Location> locations,
    double lat,
    double lng, {
    double maxDistanceMeters = 500,
  }) {
    Location? nearest;
    double minDist = double.infinity;

    for (final loc in locations) {
      if (loc.latitude == null || loc.longitude == null) continue;
      final dist = _haversineDistance(lat, lng, loc.latitude!, loc.longitude!);
      if (dist < minDist) {
        minDist = dist;
        nearest = loc;
      }
    }

    if (nearest != null && minDist <= maxDistanceMeters) {
      return nearest;
    }
    return null;
  }

  /// Haversine距離（メートル）
  double _haversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // 地球の半径（メートル）
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * pi / 180;
}
