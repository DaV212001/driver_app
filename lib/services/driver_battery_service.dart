import 'dart:async';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../config/storage_config.dart';
import '../constants/api_endpoints.dart';
import 'dio_service.dart';

class DriverBatteryService extends GetxService {
  static DriverBatteryService get to => Get.find<DriverBatteryService>();

  final Battery _battery = Battery();
  final Logger _logger = Logger();

  final RxInt batteryPercent = 100.obs;
  final Rx<BatteryState> batteryState = BatteryState.unknown.obs;
  final Rxn<DateTime> lastSentAt = Rxn<DateTime>();
  final RxString lastReportedAmount = ''.obs;
  final RxBool isReporting = false.obs;
  final RxString lastReportStatus = ''.obs;

  Timer? _periodicTimer;
  StreamSubscription<BatteryState>? _batteryStateSub;

  static bool get isInTest =>
      Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');

  // Test mode flag / mock battery level
  int? mockBatteryPercent;

  @override
  void onInit() {
    super.onInit();
    if (!isInTest) {
      _initBatteryListener();
      // Default heartbeat: periodically report every 5 minutes while active
      startPeriodicTracking();
    }
  }

  @override
  void onClose() {
    stopPeriodicTracking();
    _batteryStateSub?.cancel();
    super.onClose();
  }

  void _initBatteryListener() {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        _batteryStateSub = _battery.onBatteryStateChanged.listen(
          (state) {
            batteryState.value = state;
          },
          onError: (_) {},
        );
      }
    } catch (_) {}
  }

  /// Read real-time battery percentage from device hardware
  Future<int> getCurrentBatteryPercent() async {
    if (mockBatteryPercent != null) {
      batteryPercent.value = mockBatteryPercent!;
      return mockBatteryPercent!;
    }

    if (kIsWeb) return batteryPercent.value;

    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final level = await _battery.batteryLevel;
        batteryPercent.value = level;
        return level;
      }
    } catch (e) {
      _logger.w('Could not read hardware battery level: $e');
    }

    return batteryPercent.value;
  }

  /// Starts periodic heartbeat tracking to report battery level to backend
  void startPeriodicTracking({Duration interval = const Duration(minutes: 5)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) async {
      if (StorageConfig.isLoggedIn()) {
        await sendBatteryPercent(reason: 'periodic_heartbeat');
      }
    });

    // Trigger initial sync asynchronously if logged in
    if (StorageConfig.isLoggedIn()) {
      Future.microtask(() => sendBatteryPercent(reason: 'service_start'));
    }
  }

  /// Stop periodic timer
  void stopPeriodicTracking() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Sends the current battery percentage to AMN backend
  /// (POST /api/driver-battry-percent)
  Future<bool> sendBatteryPercent({
    int? batteryLevel,
    String? reason,
    Function(Map<String, dynamic> data)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    final driverId = StorageConfig.getDriverId() ?? '1';
    final deviceId = StorageConfig.getDeviceId();
    final level = batteryLevel ?? await getCurrentBatteryPercent();
    final dateIso = DateTime.now().toUtc().toIso8601String();

    isReporting.value = true;
    bool success = false;

    final payload = {
      'driver_id': int.tryParse(driverId) ?? driverId,
      'device_id': deviceId,
      'date': dateIso,
      'amount': level.toString(),
    };

    _logger.i('🔋 Sending battery percent ($level%) to backend [Reason: ${reason ?? 'manual'}]');

    await DioService.dioPost(
      path: ApiEndpoints.driverBatteryPercent,
      data: payload,
      onSuccess: (response) {
        success = true;
        isReporting.value = false;
        lastSentAt.value = DateTime.now();
        lastReportedAmount.value = level.toString();
        lastReportStatus.value = 'Reported $level% at ${DateTime.now().toLocal()}';

        final resData = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {'message': 'Battery percent reported successfully'};

        _logger.i('✅ Battery report confirmed by server: $resData');
        onSuccess?.call(resData);
      },
      onFailure: (error, response) {
        isReporting.value = false;
        final errorMsg = response.data is Map<String, dynamic>
            ? response.data['message']?.toString() ?? 'Failed to send battery'
            : 'Network error sending battery';
        lastReportStatus.value = 'Failed: $errorMsg';
        _logger.w('⚠️ Failed to send battery percentage: $errorMsg ($error)');
        onFailure?.call(errorMsg);
      },
    );

    return success;
  }

  /// Check elapsed time on app resume and send if heartbeat is overdue
  void checkAndSendBatteryOnResume() {
    if (!StorageConfig.isLoggedIn()) return;
    final last = lastSentAt.value;
    if (last == null || DateTime.now().difference(last).inMinutes >= 5) {
      sendBatteryPercent(reason: 'app_resumed');
    }
  }
}
