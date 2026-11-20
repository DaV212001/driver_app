import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../config/storage_config.dart';
import '../core/theme/app_colors.dart';
import '../models/delivery_task.dart';
import '../services/driver_location_update_service.dart';
import '../services/driver_order_service.dart';
import '../services/driver_socket_service.dart';
import '../services/gebeta_location_service.dart';
import '../services/notification_service.dart';
import 'deliveries_controller.dart';
import 'driver_dashboard_controller.dart';
import 'earnings_controller.dart';
import 'history_controller.dart';

class ActiveDeliveryController extends GetxController {
  final Rxn<DeliveryTask> currentTask = Rxn<DeliveryTask>();
  final RxInt currentStep = 0.obs; // 0: Heading to Store, 1: Pick up Order, 2: Deliver to Customer
  final Rxn<String> focusedTarget = Rxn<String>(); // null (auto based on status), 'pickup', 'dropoff'
  final RxString gebetaRemainingDistance = ''.obs;
  final RxString gebetaRemainingDuration = ''.obs;

  void updateGebetaRouteMetrics(String dist, String duration) {
    gebetaRemainingDistance.value = dist;
    gebetaRemainingDuration.value = duration;
  }

  void focusPickupTarget() {
    focusedTarget.value = 'pickup';
  }

  void focusDropoffTarget() {
    focusedTarget.value = 'dropoff';
  }

  void autoFocusTarget() {
    focusedTarget.value = null;
  }

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionSubscription;
  double _currentLat = 9.0082;
  double _currentLng = 38.7845;
  double _currentHeading = 45.0;

  @override
  void onInit() {
    super.onInit();
    _restorePersistedActiveTask();
  }

  Future<void> _restorePersistedActiveTask() async {
    final activeId = StorageConfig.getActiveOrderId();
    if (activeId != null && activeId.isNotEmpty) {
      final taskJsonStr = StorageConfig.getActiveTaskJson();
      if (taskJsonStr != null && taskJsonStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(taskJsonStr);
          if (decoded is Map<String, dynamic>) {
            final restored = DeliveryTask.fromJson(decoded);
            setActiveTask(restored);
            return;
          }
        } catch (_) {}
      }

      final activeType = StorageConfig.getActiveOrderType();
      final task = await DriverOrderService.fetchOrderDetail(activeId, orderType: activeType);
      if (task != null) {
        setActiveTask(task);
      }
    }
  }

  @override
  void onClose() {
    stopLocationStreaming();
    super.onClose();
  }

  void setActiveTask(DeliveryTask task) {
    currentTask.value = task;

    // Persist active order session
    final cleanId = task.id.replaceAll(RegExp(r'[^0-9]'), '');
    final idToSave = cleanId.isNotEmpty ? cleanId : task.id;
    StorageConfig.setActiveOrderId(idToSave);
    StorageConfig.setActiveOrderType(task.orderType);

    if (task.status == DeliveryStatus.placed) {
      currentStep.value = 0;
    } else if (task.status == DeliveryStatus.assigned || task.status == DeliveryStatus.headingToStore) {
      currentStep.value = 0;
      final targetNotificationStatus = task.status == DeliveryStatus.assigned ? '1' : '2';
      if (task.lastReportedNotificationStatus != targetNotificationStatus) {
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: _extractOrderId(task),
          status: targetNotificationStatus,
          task: task,
        );
      }
    } else if (task.status == DeliveryStatus.atStore) {
      currentStep.value = 1;
      if (task.lastReportedNotificationStatus != '2') {
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: _extractOrderId(task),
          status: '2',
          task: task,
        );
      }
    } else if (task.status == DeliveryStatus.pickedUp) {
      currentStep.value = 2;
      if (task.lastReportedNotificationStatus != '3') {
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: _extractOrderId(task),
          status: '3',
          task: task,
        );
      }
    } else if (task.status == DeliveryStatus.delivered) {
      currentStep.value = 3;
    } else if (task.status == DeliveryStatus.cancelled) {
      currentStep.value = 4;
    }

    // Join tracking room on Render socket server
    _initSocketTracking(task);

    // Refresh full task details in background to ensure latest sender/receiver contacts & coordinates
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (!inTest) {
      refreshTaskDetails();
    }
  }

  Future<void> refreshTaskDetails() async {
    final task = currentTask.value;
    if (task == null) return;
    final orderId = _extractOrderId(task);
    if (orderId.isEmpty) return;
    try {
      final freshTask = await DriverOrderService.fetchOrderDetail(orderId, orderType: task.orderType);
      if (freshTask != null) {
        freshTask.customerId ??= task.customerId;
        freshTask.ownerId ??= task.ownerId;
        freshTask.propertyName ??= task.propertyName;
        freshTask.lastReportedNotificationStatus ??= task.lastReportedNotificationStatus;
        currentTask.value = freshTask;
        StorageConfig.setActiveTaskJson(jsonEncode(freshTask.toJson()));
      }
    } catch (_) {}
  }

  void _initSocketTracking(DeliveryTask task) {
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (inTest) return;
    final orderId = _extractOrderId(task);
    // Start streaming immediately so GPS fixes are active and ready
    startLocationStreaming(orderId);

    if (Get.isRegistered<DriverSocketService>()) {
      DriverSocketService.to.joinOrder(orderId, orderType: task.orderType, onResult: (success) {
        if (success) {
          DriverSocketService.to.sendStatusUpdate(
            orderId: orderId,
            status: task.statusCode,
            statusName: task.statusLabel,
          );
        }
      });
    }
  }

  String _extractOrderId(DeliveryTask task) {
    final idDigits = task.id.replaceAll(RegExp(r'[^0-9]'), '');
    if (idDigits.isNotEmpty) return idDigits;
    final orderNumDigits = task.orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return orderNumDigits.isNotEmpty ? orderNumDigits : task.id;
  }

  Future<void> _syncBackendStatus(DeliveryTask task, int status) async {
    final orderId = _extractOrderId(task);
    if (orderId.isEmpty) return;

    final rawDriverId = StorageConfig.getDriverId();
    final cleanDriverId = rawDriverId?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final driverIdNum = int.tryParse(cleanDriverId);

    if (task.isCourier) {
      await DriverOrderService.updateCourierOrderStatus(
        orderId: orderId,
        status: status,
        driverId: driverIdNum,
      );
    } else if (task.isCorporate) {
      await DriverOrderService.updateCorporateOrderStatus(
        orderId: orderId,
        status: status,
        driverId: driverIdNum,
      );
    } else if (task.isPickup) {
      await DriverOrderService.updatePickupOrderStatus(
        orderId: orderId,
        status: status,
      );
    } else {
      await DriverOrderService.updateStandardOrderStatus(
        orderId: orderId,
        status: status,
        driverId: driverIdNum,
      );
    }
  }

  void startLocationStreaming(String orderId) {
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (inTest) return;
    _locationTimer?.cancel();
    _positionSubscription?.cancel();

    // 1. Stream real-time GPS fixes from device
    _positionSubscription = GebetaLocationService.getPositionStream().listen(
      (pos) {
        if (currentTask.value == null) {
          stopLocationStreaming();
          return;
        }
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
        _currentHeading = pos.heading;

        if (Get.isRegistered<DriverSocketService>()) {
          DriverSocketService.to.sendLocation(
            orderId: orderId,
            latitude: _currentLat,
            longitude: _currentLng,
            heading: _currentHeading,
            speed: pos.speed,
            accuracy: pos.accuracy,
          );
        }

        // Also sync location to REST API (POST /api/driver-location) during active order
        if (Get.isRegistered<DriverLocationUpdateService>()) {
          DriverLocationUpdateService.to.sendLocationUpdate(
            latitude: _currentLat,
            longitude: _currentLng,
            reason: 'order_active',
          );
        }
      },
      onError: (_) {},
    );

    // 2. Periodic ETA updates and dynamic distance calculation
    _locationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final task = currentTask.value;
      if (task == null) {
        stopLocationStreaming();
        return;
      }

      if (Get.isRegistered<DriverSocketService>()) {
        final destLat = (currentStep.value <= 1)
            ? (task.storeLatitude ?? 9.0082)
            : (task.customerLatitude ?? 9.0221);
        final destLng = (currentStep.value <= 1)
            ? (task.storeLongitude ?? 38.7845)
            : (task.customerLongitude ?? 38.7468);

        final distanceMeters = Geolocator.distanceBetween(
          _currentLat,
          _currentLng,
          destLat,
          destLng,
        );

        // Calculate dynamic ETA (estimated average speed ~25 km/h = 7 m/s)
        const double speedMs = 7.0;
        final remainingMins = (distanceMeters / (speedMs * 60)).ceil().clamp(1, 120);

        DriverSocketService.to.sendEta(
          orderId: orderId,
          estimatedMinutes: remainingMins,
          remainingDistanceMeters: distanceMeters,
        );
      }
    });
  }

  void stopLocationStreaming() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void toggleItem(int index) {
    final task = currentTask.value;
    if (task != null && index >= 0 && index < task.items.length) {
      task.items[index].isChecked = !task.items[index].isChecked;
      currentTask.refresh();
    }
  }

  void startDriverOnTheWayToShop() {
    final task = currentTask.value;
    if (task != null) {
      task.status = DeliveryStatus.headingToStore;
      currentStep.value = 0;
      currentTask.refresh();
      _syncTaskStatus(task);

      final orderId = _extractOrderId(task);
      if (Get.isRegistered<DriverSocketService>()) {
        DriverSocketService.to.sendStatusUpdate(
          orderId: orderId,
          status: '2',
          statusName: 'Driver on the way to shop',
          notes: 'heading_to_shop',
        );
      }

      if (orderId.isNotEmpty) {
        _syncBackendStatus(task, 2);
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: '2',
          task: task,
        );
      }

      if (Get.context != null) {
        Get.snackbar(
          'On the Way to Shop 🏬',
          'Navigating to ${task.storeName}.',
          backgroundColor: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
    }
  }

  void markArrivedAtStore() {
    final task = currentTask.value;
    if (task != null) {
      task.status = DeliveryStatus.atStore;
      currentStep.value = 1;
      currentTask.refresh();
      _syncTaskStatus(task);

      final orderId = _extractOrderId(task);
      if (Get.isRegistered<DriverSocketService>()) {
        DriverSocketService.to.sendStatusUpdate(
          orderId: orderId,
          status: '2',
          statusName: 'Driver on the way to shop',
          notes: 'at_shop',
        );
      }

      if (orderId.isNotEmpty) {
        _syncBackendStatus(task, 2);
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: '2',
          task: task,
        );
      }

      if (Get.context != null) {
        Get.snackbar(
          'Arrived at Shop',
          task.items.isNotEmpty
              ? 'Please collect and verify all items on the checklist.'
              : 'Please collect order #${task.orderNumber} for pickup.',
          backgroundColor: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
    }
  }

  void confirmPickupAndDepart() {
    final task = currentTask.value;
    if (task != null) {
      for (final item in task.items) {
        item.isChecked = true;
      }
      task.status = DeliveryStatus.pickedUp;
      currentStep.value = 2;
      currentTask.refresh();
      _syncTaskStatus(task);

      final orderId = _extractOrderId(task);
      if (Get.isRegistered<DriverSocketService>()) {
        DriverSocketService.to.sendStatusUpdate(
          orderId: orderId,
          status: '3',
          statusName: 'Driver on the way to you',
          notes: 'driver_to_you',
        );
      }

      if (orderId.isNotEmpty) {
        _syncBackendStatus(task, 3);
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: '3',
          task: task,
        );
      }

      if (Get.context != null) {
        Get.snackbar(
          'Driver on the way to you 📦',
          'Navigating to customer: ${task.customerAddress}',
          backgroundColor: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
    }
  }

  void completeDelivery() {
    final task = currentTask.value;
    if (task != null) {
      final orderId = _extractOrderId(task);
      if (Get.isRegistered<DriverSocketService>()) {
        DriverSocketService.to.sendStatusUpdate(
          orderId: orderId,
          status: '4',
          statusName: 'Deliverd',
          notes: 'delivered',
        );
        DriverSocketService.to.leaveOrder(orderId);
      }
      stopLocationStreaming();

      if (orderId.isNotEmpty) {
        _syncBackendStatus(task, 4);
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: '4',
          task: task,
        );
      }

      // Clear active order lock in StorageConfig upon successful delivery
      StorageConfig.setActiveOrderId(null);

      task.status = DeliveryStatus.delivered;
      task.completedAt = DateTime.now();

      // Record in EarningsController
      if (Get.isRegistered<EarningsController>()) {
        final earningsCtrl = Get.find<EarningsController>();
        earningsCtrl.recordCompletedDelivery(task);
      }

      // Record in HistoryController
      if (Get.isRegistered<HistoryController>()) {
        final historyCtrl = Get.find<HistoryController>();
        historyCtrl.addCompletedDelivery(task);
      }

      // Remove from DeliveriesController assigned queue
      if (Get.isRegistered<DeliveriesController>()) {
        final delCtrl = Get.find<DeliveriesController>();
        delCtrl.assignedTasks.removeWhere((t) => t.id == task.id);
      }

      // Update Dashboard controller
      if (Get.isRegistered<DriverDashboardController>()) {
        final dashCtrl = Get.find<DriverDashboardController>();
        dashCtrl.assignedTasks.removeWhere((t) => t.id == task.id);
        dashCtrl.completedTrips.value++;
        dashCtrl.todayEarnings.value += task.totalPayout;
      }

      currentTask.value = null;
      currentStep.value = 0;

      Get.defaultDialog(
        title: 'Delivery Completed! 🎉',
        titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        middleText:
            'You earned ETB ${(task.totalPayout).toStringAsFixed(2)} for this delivery.\nGreat work!',
        textConfirm: 'Done',
        confirmTextColor: Colors.white,
        onConfirm: () => Get.back(),
      );
    }
  }

  void cancelDelivery({String reason = 'Cancelled by driver'}) {
    final task = currentTask.value;
    if (task != null) {
      final orderId = _extractOrderId(task);
      if (Get.isRegistered<DriverSocketService>()) {
        DriverSocketService.to.sendStatusUpdate(
          orderId: orderId,
          status: '5',
          statusName: 'Cancelled',
          notes: reason,
        );
        DriverSocketService.to.leaveOrder(orderId);
      }
      stopLocationStreaming();

      if (orderId.isNotEmpty) {
        _syncBackendStatus(task, 5);
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: '5',
          task: task,
        );
      }

      task.status = DeliveryStatus.cancelled;
      StorageConfig.setActiveOrderId(null);

      // Record in HistoryController
      if (Get.isRegistered<HistoryController>()) {
        final historyCtrl = Get.find<HistoryController>();
        historyCtrl.addCompletedDelivery(task);
      }

      // Remove from DeliveriesController assigned queue
      if (Get.isRegistered<DeliveriesController>()) {
        final delCtrl = Get.find<DeliveriesController>();
        delCtrl.assignedTasks.removeWhere((t) => t.id == task.id);
      }

      // Remove from Dashboard controller
      if (Get.isRegistered<DriverDashboardController>()) {
        final dashCtrl = Get.find<DriverDashboardController>();
        dashCtrl.assignedTasks.removeWhere((t) => t.id == task.id);
      }

      currentTask.value = null;
      currentStep.value = 0;

      if (Get.context != null) {
        Get.snackbar(
          'Order Cancelled',
          'Order #$orderId has been cancelled.',
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
      }
    }
  }

  void _syncTaskStatus(DeliveryTask task) {
    StorageConfig.setActiveTaskJson(jsonEncode(task.toJson()));
    if (Get.isRegistered<DeliveriesController>()) {
      Get.find<DeliveriesController>().assignedTasks.refresh();
    }
    if (Get.isRegistered<DriverDashboardController>()) {
      Get.find<DriverDashboardController>().assignedTasks.refresh();
    }
  }
}
