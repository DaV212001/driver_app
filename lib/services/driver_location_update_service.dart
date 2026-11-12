import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../config/storage_config.dart';
import '../constants/api_endpoints.dart';
import 'dio_service.dart';
import 'gebeta_location_service.dart';

class DriverLocationUpdateService extends GetxService {
  static DriverLocationUpdateService get to => Get.find<DriverLocationUpdateService>();

  static bool get isInTest =>
      Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');

  final Logger _logger = Logger();

  final Rxn<DateTime> lastLocationSentAt = Rxn<DateTime>();
  final RxnDouble lastLatitude = RxnDouble();
  final RxnDouble lastLongitude = RxnDouble();
  final RxBool isSending = false.obs;
  final RxString lastStatus = ''.obs;

  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeatTimer;
  DateTime? _lastSentTime;

  /// Minimum throttling interval between REST API updates to avoid flooding the server
  static const Duration _minInterval = Duration(seconds: 5);

  @override
  void onInit() {
    super.onInit();
    // Only track if logged in and online
    if (!isInTest && StorageConfig.isLoggedIn() && StorageConfig.getIsOnline()) {
      startTracking();
    }
  }

  @override
  void onClose() {
    stopTracking();
    super.onClose();
  }

  /// Start continuous, always-on location reporting to POST /api/driver-location
  void startTracking({Duration interval = const Duration(seconds: 15)}) {
    if (isInTest) return;

    stopTracking();

    _logger.i('🛰️ Starting always-on driver location tracking (heartbeat: ${interval.inSeconds}s)');

    // 1. Listen to hardware GPS fixes with persistent foreground service notification
    try {
      final locationSettings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 3,
              intervalDuration: const Duration(seconds: 4),
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'AMN Driver Active',
                notificationText: 'Sharing live location with dispatch',
                notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
                enableWakeLock: true,
              ),
            )
          : null;

      _positionSub = GebetaLocationService.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (pos) {
          sendLocationUpdate(
            latitude: pos.latitude,
            longitude: pos.longitude,
            reason: 'gps_stream',
          );
        },
        onError: (err) {
          _logger.w('Location stream warning: $err');
        },
      );
    } catch (e) {
      _logger.w('Could not start GPS stream: $e');
    }

    // 2. Periodic heartbeat timer to ensure continuous updates even when stationary
    _heartbeatTimer = Timer.periodic(interval, (_) async {
      if (StorageConfig.isLoggedIn()) {
        await sendLocationUpdate(reason: 'heartbeat');
      }
    });

    // 3. Immediate initial fix
    if (StorageConfig.isLoggedIn()) {
      Future.microtask(() => sendLocationUpdate(reason: 'tracking_start', force: true));
    }
  }

  /// Stop continuous location reporting
  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Sends driver GPS location to backend
  /// POST https://api.amnplc.com/api/driver-location
  /// Payload:
  /// {
  ///   "agent_id": "b6c2e515-195e-498d-bdeb-af8f9dc63eb6",
  ///   "latitude": "8.9926529",
  ///   "longitude": "8.9926529",
  ///   "date": "2026-05-11 04:05:17",
  ///   "driver_id": 1
  /// }
  Future<bool> sendLocationUpdate({
    double? latitude,
    double? longitude,
    String? reason,
    bool force = false,
    Function(Map<String, dynamic> data)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    final now = DateTime.now();

    // Throttle high-frequency updates unless forced
    if (!force && _lastSentTime != null) {
      if (now.difference(_lastSentTime!) < _minInterval) {
        return false;
      }
    }

    double? lat = latitude;
    double? lng = longitude;

    // If coordinates are not provided, query current position
    if (lat == null || lng == null) {
      try {
        final pos = await GebetaLocationService.getCurrentPosition();
        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {}
    }

    // Fallback to last known position or Addis Ababa center
    lat ??= lastLatitude.value ?? GebetaLocationService.addisAbabaCenter.latitude;
    lng ??= lastLongitude.value ?? GebetaLocationService.addisAbabaCenter.longitude;

    final driverId = StorageConfig.getDriverId() ?? '1';
    final agentId = StorageConfig.getDeviceId();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    final payload = {
      'agent_id': agentId,
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'date': dateStr,
      'driver_id': int.tryParse(driverId) ?? driverId,
    };

    isSending.value = true;
    bool success = false;

    _logger.d('📍 Reporting driver location [$lat, $lng] via POST /driver-location [Reason: ${reason ?? 'manual'}]');

    await DioService.dioPost(
      path: ApiEndpoints.driverLocation,
      data: payload,
      onSuccess: (response) {
        success = true;
        isSending.value = false;
        _lastSentTime = DateTime.now();
        lastLocationSentAt.value = _lastSentTime;
        lastLatitude.value = lat;
        lastLongitude.value = lng;
        lastStatus.value = 'Updated at $dateStr';

        final resData = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {'message': 'Driver location updated successfully'};

        onSuccess?.call(resData);
      },
      onFailure: (error, response) {
        isSending.value = false;
        final errorMsg = response.data is Map<String, dynamic>
            ? response.data['message']?.toString() ?? 'Failed to send driver location'
            : 'Network error sending driver location';
        lastStatus.value = 'Failed: $errorMsg';
        _logger.w('⚠️ Driver location update error: $errorMsg');
        onFailure?.call(errorMsg);
      },
    );

    return success;
  }
}
