import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/storage_config.dart';
import '../../constants/constants.dart';
import '../../constants/pages.dart';
import '../../controllers/active_delivery_controller.dart';
import '../../controllers/driver_dashboard_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/delivery_task.dart';
import '../../services/driver_order_service.dart';
import '../../services/driver_socket_service.dart';
import '../../services/notification_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final DeliveryTask? taskArgument;

  const OrderDetailScreen({super.key, this.taskArgument});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late DeliveryTask _task;

  DeliveryTask get task => _task;

  @override
  void initState() {
    super.initState();
    final argTask = widget.taskArgument ?? (Get.arguments as DeliveryTask?);
    if (argTask != null) {
      _task = argTask;
    } else {
      final activeId = StorageConfig.getActiveOrderId();
      if (activeId != null && activeId.isNotEmpty) {
        _task = DeliveryTask(
          id: activeId,
          orderNumber: 'AMN-$activeId',
          storeName: 'Active Order #$activeId',
          storeCategory: 'Delivery',
          storeAddress: '',
          storeDistanceKm: 0.0,
          customerName: 'Customer',
          customerPhone: '',
          customerAddress: '',
          customerDistanceKm: 0.0,
          payoutAmount: 0.0,
          tipAmount: 0.0,
          items: const [],
          status: DeliveryStatus.assigned,
          createdAt: DateTime.now(),
        );
        _fetchRealOrderDetail(activeId);
      } else {
        _task = _fallbackTask;
      }
    }
    if (Get.isRegistered<ActiveDeliveryController>()) {
      final activeCtrl = Get.find<ActiveDeliveryController>();
      if (activeCtrl.currentTask.value?.id != _task.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          activeCtrl.setActiveTask(_task);
        });
      }
    }
  }

  Future<void> _fetchRealOrderDetail(String orderId) async {
    final realTask = await DriverOrderService.fetchOrderDetail(orderId, orderType: _task.orderType);
    if (realTask != null && mounted) {
      setState(() {
        _task = realTask;
      });
      if (Get.isRegistered<ActiveDeliveryController>()) {
        Get.find<ActiveDeliveryController>().setActiveTask(realTask);
      }
    }
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      Get.snackbar('Notice', 'Phone number not available', backgroundColor: Colors.white);
      return;
    }
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      Get.snackbar('Dialer Notice', 'Dialing $phoneNumber...', backgroundColor: Colors.white);
    }
  }

  Future<void> _sendSms(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      Get.snackbar('Notice', 'Phone number not available', backgroundColor: Colors.white);
      return;
    }
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('sms:$cleanNumber');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      Get.snackbar('SMS Notice', 'Opening messaging for $phoneNumber...', backgroundColor: Colors.white);
    }
  }

  Future<void> _launchNavigationTo({
    double? lat,
    double? lng,
    required String address,
  }) async {
    Uri url;
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    } else {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    }

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      Get.snackbar('Navigation Notice', 'Opening map for $address...', backgroundColor: Colors.white);
    }
  }

  Future<void> _acceptOrder() async {
    setState(() {
      _task.status = DeliveryStatus.assigned;
    });
    final cleanOrderId = _task.id.replaceAll(RegExp(r'[^0-9]'), '');
    final activeId = cleanOrderId.isNotEmpty ? cleanOrderId : _task.id;
    StorageConfig.setActiveOrderId(activeId);
    StorageConfig.setActiveOrderType(_task.orderType);
    StorageConfig.setActiveTaskJson(jsonEncode(_task.toJson()));

    final rawDriverId = StorageConfig.getDriverId() ?? '6';
    final cleanDriverId = rawDriverId.replaceAll(RegExp(r'[^0-9]'), '');
    final driverIdNum = int.tryParse(cleanDriverId) ?? 6;

    if (cleanOrderId.isNotEmpty) {
      // 1. Immediately trigger socket tracking room join and status update
      if (Get.isRegistered<DriverSocketService>()) {
        DriverSocketService.to.joinOrder(cleanOrderId, orderType: _task.orderType, onResult: (success) {
          if (success) {
            DriverSocketService.to.sendStatusUpdate(
              orderId: cleanOrderId,
              status: '1',
              statusName: 'Order Accepted',
              notes: 'Driver accepted the order',
            );
          }
        });
      }

      // 2. Dispatch to correct backend endpoint strictly based on orderType
      if (_task.isCourier) {
        await DriverOrderService.updateCourierOrderStatus(
          orderId: cleanOrderId,
          status: 1,
          driverId: driverIdNum,
          onSuccess: (data) {
            final senderId = data['data']?['sender_user_id'] ?? data['sender_user_id'];
            if (senderId != null) {
              _task.customerId = senderId;
              StorageConfig.setActiveTaskJson(jsonEncode(_task.toJson()));
            }
          },
        );
      } else if (_task.isCorporate) {
        await DriverOrderService.updateCorporateOrderStatus(
          orderId: cleanOrderId,
          status: 1,
          driverId: driverIdNum,
        );
      } else if (_task.isPickup) {
        await DriverOrderService.updatePickupOrderStatus(
          orderId: cleanOrderId,
          status: 1,
        );
      } else {
        await DriverOrderService.acceptOrder(
          orderId: cleanOrderId,
          driverId: driverIdNum,
        );
      }

      // 3. Dispatch customer & store owner status push notifications
      NotificationService.instance.notifyOrderStatusChanged(
        orderId: cleanOrderId,
        status: '1',
        task: _task,
        customerId: _task.customerId,
        ownerId: _task.ownerId,
        propertyName: _task.propertyName ?? _task.storeName,
      );
    }
    if (Get.isRegistered<ActiveDeliveryController>()) {
      Get.find<ActiveDeliveryController>().setActiveTask(_task);
    }
    if (Get.isRegistered<DriverDashboardController>()) {
      final dashCtrl = Get.find<DriverDashboardController>();
      dashCtrl.activeAcceptedTask.value = _task;
      dashCtrl.assignedTasks.refresh();
    }
    Get.snackbar(
      'Order Accepted! 🎉',
      'Order #${_task.orderNumber} is now Accepted (Status 1). You can now begin your trip to the shop.',
      backgroundColor: AppColors.onlineGreen,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
    );
  }

  void _startTripToShop() {
    setState(() {
      _task.status = DeliveryStatus.headingToStore;
    });
    if (Get.isRegistered<ActiveDeliveryController>()) {
      Get.find<ActiveDeliveryController>().startDriverOnTheWayToShop();
    }
    if (Get.isRegistered<DriverDashboardController>()) {
      Get.find<DriverDashboardController>().assignedTasks.refresh();
    }
    Get.snackbar(
      'Driver on the way to shop 🏬',
      'Heading to ${_task.storeName}. Tap Google Maps for turn-by-turn navigation.',
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
    );
  }

  void _confirmArrivedAtStore() {
    setState(() {
      _task.status = DeliveryStatus.atStore;
    });
    if (Get.isRegistered<ActiveDeliveryController>()) {
      Get.find<ActiveDeliveryController>().markArrivedAtStore();
    }
    if (Get.isRegistered<DriverDashboardController>()) {
      Get.find<DriverDashboardController>().assignedTasks.refresh();
    }
    Get.snackbar(
      'Arrived at Shop 🏬',
      'You have arrived at ${_task.storeName}. Please collect the order for pickup.',
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
    );
  }

  void _confirmPickupAndDepart() {
    setState(() {
      for (final item in _task.items) {
        item.isChecked = true;
      }
      _task.status = DeliveryStatus.pickedUp;
    });
    if (Get.isRegistered<ActiveDeliveryController>()) {
      Get.find<ActiveDeliveryController>().confirmPickupAndDepart();
    }
    if (Get.isRegistered<DriverDashboardController>()) {
      Get.find<DriverDashboardController>().assignedTasks.refresh();
    }
    Get.snackbar(
      'Driver on the way to you 📦',
      'Departing store. Heading to customer at ${_task.customerAddress}.',
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
    );
  }

  void _confirmDeliveryComplete() {
    setState(() {
      _task.status = DeliveryStatus.delivered;
      _task.completedAt = DateTime.now();
    });
    StorageConfig.setActiveOrderId(null);
    if (Get.isRegistered<ActiveDeliveryController>()) {
      Get.find<ActiveDeliveryController>().completeDelivery();
    }
    if (Get.isRegistered<DriverDashboardController>()) {
      final dashCtrl = Get.find<DriverDashboardController>();
      dashCtrl.activeAcceptedTask.value = null;
      dashCtrl.assignedTasks.refresh();
    }
    Get.snackbar(
      'Deliverd! 🎉',
      'Order #${_task.orderNumber} delivered successfully. ETB ${_task.totalPayout.toStringAsFixed(2)} credited to your wallet.',
      backgroundColor: AppColors.onlineGreen,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
    );

    // Return to main navigation once order has been delivered
    Future.delayed(const Duration(milliseconds: 1200), () {
      Get.offAllNamed(Pages.mainNavigation);
    });
  }

  Future<void> _launchExternalNavigation() async {
    final isHeadingToStore = _task.status == DeliveryStatus.headingToStore || _task.status == DeliveryStatus.assigned;
    final destLat = isHeadingToStore ? _task.storeLatitude : _task.customerLatitude;
    final destLng = isHeadingToStore ? _task.storeLongitude : _task.customerLongitude;
    final destAddress = isHeadingToStore ? '${_task.storeName}, ${_task.storeAddress}' : _task.customerAddress;

    Uri url;
    if (destLat != null && destLng != null && destLat != 0.0 && destLng != 0.0) {
      url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving');
    } else {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(destAddress)}');
    }

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      Get.snackbar('Navigation Notice', 'Opening map for $destAddress...', backgroundColor: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bool isActiveOrder = task.status == DeliveryStatus.assigned ||
        task.status == DeliveryStatus.headingToStore ||
        task.status == DeliveryStatus.atStore ||
        task.status == DeliveryStatus.pickedUp;

    return PopScope(
      canPop: !isActiveOrder,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (!Get.testMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
            Get.snackbar(
              'Order in Progress 🔒',
              'You cannot leave this screen until order #${task.orderNumber} is delivered.',
              snackPosition: SnackPosition.TOP,
              backgroundColor: const Color(0xFF1E293B),
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.all(12),
              borderRadius: 8,
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: !isActiveOrder,
          title: AutoSizeText(
          'Order #${task.orderNumber}',
          maxLines: 1,
          minFontSize: 13,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          Obx(() {
            final isDark = ThemeController.to.isDarkMode;
            return IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
                color: isDark ? AppColors.starGold : AppColors.onSurfaceVariant,
              ),
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              onPressed: ThemeController.to.toggleTheme,
            );
          }),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: StatusBadge(
                label: task.statusLabel,
                backgroundColor: task.statusBgColor,
                textColor: task.statusColor,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Route & Logistics Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ROUTE LOGISTICS',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Store Pickup
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoSizeText(
                              'PICKUP FROM STORE',
                              maxLines: 1,
                              minFontSize: 8,
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 9.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AutoSizeText(
                              task.storeName,
                              maxLines: 1,
                              minFontSize: 11,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            AutoSizeText(
                              '${task.storeAddress} (${task.storeDistanceKm} km)',
                              maxLines: 1,
                              minFontSize: 9,
                              style: textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.map_rounded, size: 18),
                            color: AppColors.primary,
                            tooltip: 'In-App Gebeta Map',
                            onPressed: () {
                              if (Get.isRegistered<ActiveDeliveryController>()) {
                                final ctrl = Get.find<ActiveDeliveryController>();
                                ctrl.setActiveTask(_task);
                                ctrl.focusPickupTarget();
                              }
                              Get.toNamed(Pages.activeDelivery, arguments: _task);
                            },
                          ),
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.navigation_rounded, size: 18),
                            color: AppColors.primary,
                            tooltip: 'Google Maps Directions',
                            onPressed: () => _launchNavigationTo(
                              lat: task.storeLatitude,
                              lng: task.storeLongitude,
                              address: '${task.storeName}, ${task.storeAddress}',
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.phone_rounded, size: 18),
                            color: AppColors.primary,
                            tooltip: 'Call Store / Sender',
                            onPressed: () => _makePhoneCall(task.storePhone),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Connector line
                  Padding(
                    padding: const EdgeInsets.only(left: 17),
                    child: Container(
                      width: 2,
                      height: 22,
                      color: AppColors.outlineVariant,
                    ),
                  ),

                  // Customer Dropoff
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.onlineGreenBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 20,
                          color: AppColors.onlineGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoSizeText(
                              'DELIVER TO CUSTOMER',
                              maxLines: 1,
                              minFontSize: 8,
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 9.5,
                                color: AppColors.onlineGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AutoSizeText(
                              task.customerName,
                              maxLines: 1,
                              minFontSize: 11,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            AutoSizeText(
                              '${task.customerAddress} (${task.customerDistanceKm} km)',
                              maxLines: 1,
                              minFontSize: 9,
                              style: textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.map_rounded, size: 18),
                            color: AppColors.onlineGreen,
                            tooltip: 'In-App Gebeta Map',
                            onPressed: () {
                              if (Get.isRegistered<ActiveDeliveryController>()) {
                                final ctrl = Get.find<ActiveDeliveryController>();
                                ctrl.setActiveTask(_task);
                                ctrl.focusDropoffTarget();
                              }
                              Get.toNamed(Pages.activeDelivery, arguments: _task);
                            },
                          ),
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.navigation_rounded, size: 18),
                            color: AppColors.primary,
                            tooltip: 'Google Maps Directions',
                            onPressed: () => _launchNavigationTo(
                              lat: task.customerLatitude,
                              lng: task.customerLongitude,
                              address: task.customerAddress,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.phone_rounded, size: 18),
                            color: AppColors.primary,
                            tooltip: 'Call Customer',
                            onPressed: () => _makePhoneCall(task.customerPhone),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.sms_outlined, size: 18),
                            color: AppColors.primary,
                            tooltip: 'SMS Customer',
                            onPressed: () => _sendSms(task.customerPhone),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Special Delivery Notes
                  if (task.deliveryNotes != null && task.deliveryNotes!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmberBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warningAmber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.warningAmber,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AutoSizeText(
                                  'Customer Note',
                                  maxLines: 1,
                                  minFontSize: 9,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                    color: AppColors.warningAmber,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  task.deliveryNotes!,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. Order Items Checklist or Package Information
            if (task.items.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AutoSizeText(
                          'ORDER ITEMS (${task.itemCount})',
                          maxLines: 1,
                          minFontSize: 9,
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                        AutoSizeText(
                          task.storeCategory,
                          maxLines: 1,
                          minFontSize: 9,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    ...task.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: item.isChecked
                                    ? AppColors.onlineGreenBg
                                    : AppColors.primaryContainer.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(
                                  item.isChecked
                                      ? Icons.check_rounded
                                      : Icons.inventory_2_rounded,
                                  size: 16,
                                  color: item.isChecked
                                      ? AppColors.onlineGreen
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AutoSizeText(
                                    '${item.quantity}x ${item.name}',
                                    maxLines: 1,
                                    minFontSize: 10,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  if (item.unitPrice != null)
                                    AutoSizeText(
                                      '${formatEtb(item.unitPrice!)} each',
                                      maxLines: 1,
                                      minFontSize: 9,
                                      style: textTheme.bodySmall?.copyWith(fontSize: 10.5),
                                    ),
                                ],
                              ),
                            ),
                            if (item.unitPrice != null)
                              AutoSizeText(
                                formatEtb(item.totalPrice),
                                maxLines: 1,
                                minFontSize: 10,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ] else ...[
              // Package / Dispatch Details Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AutoSizeText(
                          task.isCourier
                              ? 'PACKAGE DETAILS'
                              : (task.isCorporate ? 'DISPATCH DETAILS' : 'ORDER DETAILS'),
                          maxLines: 1,
                          minFontSize: 9,
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.orderTypeLabel,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(
                              task.isCourier
                                  ? Icons.local_shipping_outlined
                                  : Icons.inventory_2_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.isCourier
                                    ? 'Courier Package (Order #${task.orderNumber})'
                                    : (task.isCorporate
                                        ? 'Corporate Shipment (Order #${task.orderNumber})'
                                        : '${task.storeName}${task.itemCount > 0 ? ' • ${task.itemCount} items' : ''}'),
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              if (task.deliveryNotes != null && task.deliveryNotes!.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  task.deliveryNotes!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 3. Driver Earnings & Payment Breakdown
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYOUT & PAYMENT SUMMARY',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Delivery Fee', style: textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                      AutoSizeText(formatEtb(task.payoutAmount), maxLines: 1, minFontSize: 10, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Driver Earnings',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      AutoSizeText(
                        formatEtb(task.totalPayout),
                        maxLines: 1,
                        minFontSize: 12,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.onlineGreen,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Payment method pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payment_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AutoSizeText(
                            'Payment Method: ${task.paymentMethod}',
                            maxLines: 1,
                            minFontSize: 9,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Action Buttons based on delivery state
            if (_task.status == DeliveryStatus.cancelled) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cancel_rounded, size: 36, color: AppColors.error),
                    const SizedBox(height: 8),
                    const AutoSizeText(
                      'Order Cancelled',
                      maxLines: 1,
                      minFontSize: 12,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.until((route) => route.settings.name == Pages.mainNavigation || route.isFirst);
                        },
                        icon: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                        label: const Text('Return to Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_task.status == DeliveryStatus.delivered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.onlineGreenBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.onlineGreen.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 36, color: AppColors.onlineGreen),
                    const SizedBox(height: 8),
                    const AutoSizeText(
                      'Deliverd 🎉',
                      maxLines: 1,
                      minFontSize: 12,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.onlineGreen,
                      ),
                    ),
                    if (_task.completedAt != null)
                      AutoSizeText(
                        'Delivered on ${DateFormat('MMM d, yyyy • h:mm a').format(_task.completedAt!)}',
                        maxLines: 1,
                        minFontSize: 10,
                        style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Get.until((route) => route.settings.name == Pages.mainNavigation || route.isFirst);
                        },
                        icon: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                        label: const Text('Return to Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.onlineGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Current Destination & Navigation Banner (Shows where they are heading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_task.status == DeliveryStatus.pickedUp)
                      ? AppColors.onlineGreenBg
                      : AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_task.status == DeliveryStatus.pickedUp)
                      ? AppColors.onlineGreen.withValues(alpha: 0.4)
                      : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_task.status == DeliveryStatus.pickedUp)
                          ? Icons.navigation_rounded
                          : Icons.storefront_rounded,
                      color: (_task.status == DeliveryStatus.pickedUp)
                          ? AppColors.onlineGreen
                          : AppColors.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_task.status == DeliveryStatus.pickedUp)
                                ? 'CURRENT DESTINATION: CUSTOMER'
                                : (_task.status == DeliveryStatus.headingToStore
                                    ? 'ON THE WAY TO SHOP'
                                    : (_task.status == DeliveryStatus.atStore
                                        ? 'CURRENT STOP: AT SHOP'
                                        : (_task.status == DeliveryStatus.assigned
                                            ? 'ACCEPTED: DESTINATION SHOP'
                                            : 'ORDER PLACED: PENDING ACCEPT'))),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: (_task.status == DeliveryStatus.pickedUp)
                                  ? AppColors.onlineGreen
                                  : AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (_task.status == DeliveryStatus.pickedUp)
                                ? _task.customerAddress
                                : _task.storeName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            (_task.status == DeliveryStatus.pickedUp)
                                ? '${_task.customerDistanceKm} km away • Delivery destination'
                                : '${_task.storeDistanceKm} km away • ${_task.storeAddress}',
                            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Navigation Action Buttons: External Google Maps & Live In-App Navigation
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _launchExternalNavigation,
                      icon: const Icon(Icons.navigation_rounded, color: AppColors.primary, size: 18),
                      label: const AutoSizeText(
                        'Google Maps',
                        maxLines: 1,
                        minFontSize: 10,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (Get.isRegistered<ActiveDeliveryController>()) {
                          Get.find<ActiveDeliveryController>().setActiveTask(_task);
                        }
                        Get.toNamed(Pages.activeDelivery, arguments: _task);
                      },
                      icon: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
                      label: const AutoSizeText(
                        'Live In-App Map',
                        maxLines: 1,
                        minFontSize: 10,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Status Advancement Controls: Advance status immediately
              if (_task.status == DeliveryStatus.placed) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _acceptOrder,
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const AutoSizeText(
                      'Accept Order (Status 1: Accepted)',
                      maxLines: 1,
                      minFontSize: 11,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.onlineGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.onSurfaceVariant),
                    label: const Text(
                      'Decline Offer',
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ] else if (_task.status == DeliveryStatus.assigned) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startTripToShop,
                    icon: const Icon(Icons.directions_car_rounded, size: 20),
                    label: const AutoSizeText(
                      'Start Trip: Driver on the way to shop',
                      maxLines: 1,
                      minFontSize: 11,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
              ] else if (_task.status == DeliveryStatus.headingToStore || _task.status == DeliveryStatus.atStore) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmPickupAndDepart,
                    icon: const Icon(Icons.inventory_2_rounded, size: 20),
                    label: const AutoSizeText(
                      'Confirm Pickup: Driver on the way to you',
                      maxLines: 1,
                      minFontSize: 11,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
                if (_task.status == DeliveryStatus.headingToStore) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _confirmArrivedAtStore,
                      icon: const Icon(Icons.storefront_rounded, size: 18),
                      label: const AutoSizeText(
                        'Mark Arrived at Shop',
                        maxLines: 1,
                        minFontSize: 11,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ] else if (_task.status == DeliveryStatus.pickedUp) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmDeliveryComplete,
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const AutoSizeText(
                      'Confirm Deliverd',
                      maxLines: 1,
                      minFontSize: 11,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.onlineGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
    );
  }

  static DeliveryTask get _fallbackTask => DeliveryTask(
        id: 'TSK-0000',
        orderNumber: 'Order',
        storeName: 'Active Delivery Order',
        storeCategory: 'Delivery',
        storeAddress: '',
        storeDistanceKm: 0.0,
        customerName: 'Customer',
        customerPhone: '',
        customerAddress: '',
        customerDistanceKm: 0.0,
        payoutAmount: 0.0,
        tipAmount: 0.0,
        items: const [],
        status: DeliveryStatus.placed,
        createdAt: DateTime.now(),
      );
}
