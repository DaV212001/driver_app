import 'dart:math' as math;
import 'package:gebeta_gl/gebeta_gl.dart';

class GebetaRoute {
  final List<LatLng> points;
  final double totalDistanceMeters;
  final double timeTakenSeconds;

  const GebetaRoute({
    required this.points,
    required this.totalDistanceMeters,
    required this.timeTakenSeconds,
  });

  /// Human-readable distance (e.g. "2.4 km" or "850 m")
  String get formattedDistance {
    if (totalDistanceMeters >= 1000) {
      final km = totalDistanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${totalDistanceMeters.round()} m';
  }

  /// Human-readable travel duration (e.g. "12 mins")
  String get formattedDuration {
    if (timeTakenSeconds < 60) return '< 1 min';
    final minutes = (timeTakenSeconds / 60.0).round();
    if (minutes < 60) return '$minutes mins';
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) return '${hours}h';
    return '${hours}h ${remainingMins}m';
  }

  /// Center point of the route
  LatLng get center {
    if (points.isEmpty) return const LatLng(9.0192, 38.7525);
    double sumLat = 0;
    double sumLng = 0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  /// Bounding box covering all coordinates with a safe margin
  LatLngBounds get bounds {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(9.0100, 38.7400),
        northeast: const LatLng(9.0300, 38.7700),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Add 10% padding to bounds
    final latPadding = math.max((maxLat - minLat) * 0.1, 0.002);
    final lngPadding = math.max((maxLng - minLng) * 0.1, 0.002);

    return LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  /// Returns interpolated position along the path from 0.0 (origin) to 1.0 (destination)
  LatLng positionAtProgress(double progress) {
    if (points.isEmpty) return const LatLng(9.0192, 38.7525);
    if (points.length == 1 || progress <= 0.0) return points.first;
    if (progress >= 1.0) return points.last;

    final targetIndex = (progress * (points.length - 1)).clamp(0.0, (points.length - 1).toDouble());
    final index1 = targetIndex.floor();
    final index2 = math.min(index1 + 1, points.length - 1);
    final fraction = targetIndex - index1;

    final p1 = points[index1];
    final p2 = points[index2];

    final lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * fraction;
    return LatLng(lat, lng);
  }

  /// Fallback route generator: generates a realistic curved route between two points
  static GebetaRoute generateFallbackRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    final pts = <LatLng>[];
    const steps = 20;

    // Direct distance using equirectangular approximation
    final dLat = (destLat - originLat) * 111000.0;
    final dLng = (destLng - originLng) * 111000.0 * math.cos(originLat * math.pi / 180.0);
    final directDistanceMeters = math.sqrt(dLat * dLat + dLng * dLng);
    // Road routes are typically ~1.25x direct distance
    final roadDistanceMeters = math.max(directDistanceMeters * 1.25, 600.0);
    // Estimated drive speed: 25 km/h in city traffic (~6.94 m/s)
    final timeSeconds = (roadDistanceMeters / 6.94).clamp(120.0, 3600.0);

    // Generate a gentle serpentine path along roads
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      // Perpendicular offset for realistic road deviation
      final curve = math.sin(t * math.pi) * 0.0018;
      final lat = originLat + (destLat - originLat) * t + curve * 0.5;
      final lng = originLng + (destLng - originLng) * t + curve;
      pts.add(LatLng(lat, lng));
    }

    return GebetaRoute(
      points: pts,
      totalDistanceMeters: roadDistanceMeters,
      timeTakenSeconds: timeSeconds,
    );
  }

  @override
  String toString() =>
      'GebetaRoute(points: ${points.length}, distance: $formattedDistance, duration: $formattedDuration)';
}
