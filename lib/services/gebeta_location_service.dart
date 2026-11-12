import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gebeta_gl/gebeta_gl.dart';

import '../config/storage_config.dart';
import '../models/gebeta_place_suggestion.dart';
import '../models/gebeta_route.dart';
import '../utils/location_utils.dart';
import '../widgets/dialogs/location_prominent_disclosure_dialog.dart';

class GebetaLocationService {
  static const String apiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjb21wYW55bmFtZSI6IkFtYW51ZWwiLCJkZXNjcmlwdGlvbiI6IjgyMGIyYzY2LThjOWYtNDAxOS1hZjljLWYxNjU5M2U0ZWEyNyIsImlkIjoiYjIwNTliNDktMTQ2OC00YzZhLWI5YjktMjJhNjljZDNjNTA1IiwidXNlcm5hbWUiOiJhbWFudWVsdGlsYWh1biJ9.TPBHHhfOYMcHNO8Y8h52SCivIROcXAdmiAgHBOapkeQ';

  static const String gebetaStandardStyle =
      'https://tiles.gebeta.app/styles/standard/style.json';

  static const LatLng addisAbabaCenter = LatLng(9.0209, 38.7469);

  /// In-memory cache for coordinates to reverse-geocoded addresses
  static final Map<String, String> _addressCache = {};

  /// In-memory cache for forward geocoding place search suggestions
  static final Map<String, List<GebetaPlaceSuggestion>> _searchCache = {};

  /// In-memory cache for Gebeta Maps routes
  static final Map<String, GebetaRoute> _routeCache = {};

  /// Configure native MapLibre HTTP engine with required Origin and Authorization headers
  static Future<void> configureMapHeaders() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await setHttpHeaders({
          'Origin': 'https://gebeta.app',
          'Authorization': 'Bearer $apiKey',
        });
      }
    } catch (_) {}
  }

  static Future<bool>? _ongoingPermissionCheck;

  /// Ensure GPS permission is granted and location services are enabled.
  /// Strictly enforces Google Play Policy: The in-app prominent disclosure dialog
  /// is ALWAYS displayed BEFORE the Android OS system runtime permission prompt is triggered.
  static Future<bool> ensureLocationPermission({bool isGoingOnline = false}) async {
    // Never request or check location before the driver is authenticated
    if (!StorageConfig.isLoggedIn()) {
      return false;
    }

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true;
    }

    if (_ongoingPermissionCheck != null) {
      return _ongoingPermissionCheck!;
    }

    _ongoingPermissionCheck = _ensureLocationPermissionInternal(isGoingOnline: isGoingOnline);
    try {
      return await _ongoingPermissionCheck!;
    } finally {
      _ongoingPermissionCheck = null;
    }
  }

  static Future<bool> _ensureLocationPermissionInternal({bool isGoingOnline = false}) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      // Google Play Policy Requirement:
      // In-app prominent disclosure MUST be shown BEFORE requesting runtime permission from the user!
      if (permission == LocationPermission.denied) {
        if (!StorageConfig.hasAgreedLocationDisclosure()) {
          final accepted = await LocationProminentDisclosureDialog.show();
          if (!accepted) {
            return false;
          }
          await StorageConfig.setLocationDisclosureAgreed(true);
        }

        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      // If going online and driver hasn't agreed to background location disclosure yet
      if (isGoingOnline && !StorageConfig.hasAgreedLocationDisclosure()) {
        final accepted = await LocationProminentDisclosureDialog.show();
        if (!accepted) {
          return false;
        }
        await StorageConfig.setLocationDisclosureAgreed(true);
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return false;
      }

      // Ensure device GPS / location hardware is turned on
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return false;
        }
      }

      // When going online on Android 13+, also ensure notification permission is granted
      // so the foreground service persistent notification ("AMN Driver Active") can display.
      if (isGoingOnline && Platform.isAndroid) {
        try {
          final isAllowed = await AwesomeNotifications().isNotificationAllowed();
          if (!isAllowed) {
            await AwesomeNotifications().requestPermissionToSendNotifications();
          }
        } catch (_) {}
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Get current GPS position with permission checks and safe fallback
  static Future<Position?> getCurrentPosition() async {
    // Never query location before the driver is authenticated
    if (!StorageConfig.isLoggedIn()) {
      return null;
    }
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return Position(
        latitude: 9.0209,
        longitude: 38.7469,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 2355.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    try {
      final hasPermission = await ensureLocationPermission();
      if (!hasPermission) {
        return await Geolocator.getLastKnownPosition();
      }

      final lastKnown = await Geolocator.getLastKnownPosition();

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        return lastKnown;
      }
    } catch (_) {
      return null;
    }
  }

  /// Real-time stream of GPS position updates for live map tracking
  static Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    // Never stream location before the driver is authenticated
    if (!StorageConfig.isLoggedIn()) {
      return const Stream.empty();
    }
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const Stream.empty();
    }
    try {
      if (locationSettings != null) {
        return Geolocator.getPositionStream(locationSettings: locationSettings);
      }

      final isOnline = StorageConfig.getIsOnline();

      if (Platform.isAndroid) {
        return Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1,
            intervalDuration: const Duration(seconds: 3),
            // Background foreground service is only attached when the driver is online
            foregroundNotificationConfig: isOnline
                ? const ForegroundNotificationConfig(
                    notificationTitle: 'AMN Driver Active',
                    notificationText: 'Sharing live location with dispatch',
                    notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
                    enableWakeLock: true,
                  )
                : null,
          ),
        );
      } else if (Platform.isIOS) {
        return Geolocator.getPositionStream(
          locationSettings: AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1,
            activityType: ActivityType.automotiveNavigation,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: isOnline,
          ),
        );
      }

      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1,
        ),
      );
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Reverse geocode latitude and longitude using Gebeta Maps API
  static Future<String> reverseGeocode(double lat, double lng) async {
    final cacheKey = '${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}';
    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey]!;
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final url =
          'https://mapapi.gebeta.app/api/v1/route/revgeocoding?lat=$lat&lon=$lng&apiKey=$apiKey';

      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data is List && data.isNotEmpty) {
          final first = data.first;
          final name = first['name']?.toString() ?? '';
          final city = first['City']?.toString() ?? '';
          final country = first['Country']?.toString() ?? '';

          final parts = [name, city, country]
              .where((s) => s.trim().isNotEmpty)
              .toList();

          if (parts.isNotEmpty) {
            final formatted = LocationUtils.prettifyAddress(parts.join(', '));
            _addressCache[cacheKey] = formatted;
            return formatted;
          }
        }
      }
    } catch (_) {}

    final fallback = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} (Addis Ababa)';
    _addressCache[cacheKey] = fallback;
    return fallback;
  }

  /// Forward geocode / search places by name query using Gebeta Maps Geocoding API.
  /// (e.g. typing "Bole" returns all places with Bole in their name:
  /// Bole, Bole Medhane Alem, Bole Arabsa, Bole Brass, etc.)
  static Future<List<GebetaPlaceSuggestion>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final cacheKey = trimmed.toLowerCase();
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final url =
          'https://mapapi.gebeta.app/api/v1/route/geocoding?name=${Uri.encodeComponent(trimmed)}&apiKey=$apiKey';

      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data is List) {
          final results = data
              .map((item) => GebetaPlaceSuggestion.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .where((item) => item.latitude != 0.0 && item.longitude != 0.0)
              .toList();
          _searchCache[cacheKey] = results;
          return results;
        }
      }
    } catch (_) {}

    return [];
  }

  /// Fetch road route between origin and destination coordinates using Gebeta Maps Directions API.
  /// Falls back gracefully to realistic interpolated polyline if offline or API error.
  static Future<GebetaRoute> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final cacheKey =
        '${originLat.toStringAsFixed(4)}_${originLng.toStringAsFixed(4)}_${destLat.toStringAsFixed(4)}_${destLng.toStringAsFixed(4)}';
    if (_routeCache.containsKey(cacheKey)) {
      return _routeCache[cacheKey]!;
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final url =
          'https://mapapi.gebeta.app/api/route/direction/?origin=$originLat,$originLng&destination=$destLat,$destLng&apiKey=$apiKey';

      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final rawDirection = data['direction'];
        final totalDist = double.tryParse(data['totalDistance']?.toString() ?? '0') ?? 0.0;
        final timeTaken = double.tryParse(data['timetaken']?.toString() ?? '0') ?? 0.0;

        if (rawDirection is List && rawDirection.isNotEmpty) {
          final pts = <LatLng>[];
          for (final item in rawDirection) {
            if (item is List && item.length >= 2) {
              final lat = double.tryParse(item[0]?.toString() ?? '');
              final lng = double.tryParse(item[1]?.toString() ?? '');
              if (lat != null && lng != null) {
                pts.add(LatLng(lat, lng));
              }
            }
          }

          if (pts.isNotEmpty) {
            final route = GebetaRoute(
              points: pts,
              totalDistanceMeters: totalDist > 0 ? totalDist : pts.length * 50.0,
              timeTakenSeconds: timeTaken > 0 ? timeTaken : 600.0,
            );
            _routeCache[cacheKey] = route;
            return route;
          }
        }
      }
    } catch (_) {}

    final fallback = GebetaRoute.generateFallbackRoute(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );
    _routeCache[cacheKey] = fallback;
    return fallback;
  }
}
