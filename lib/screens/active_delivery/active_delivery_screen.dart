import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/constants.dart';
import '../../constants/pages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../controllers/active_delivery_controller.dart';
import '../../models/delivery_task.dart';
import '../dashboard/widgets/driver_map_canvas.dart';

class ActiveDeliveryScreen extends StatelessWidget {
  const ActiveDeliveryScreen({super.key});

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

  void _showNavigationSheet(BuildContext context, DeliveryTask? task) {
    if (task == null) return;
    final controller = Get.find<ActiveDeliveryController>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Directions & Navigation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose in-app Gebeta live routing or external Google Maps',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // In-App Gebeta Routing Section
                  const Text(
                    'IN-APP GEBETA MAPS ROUTE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.25),
                      child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      'Pickup: ${task.propertyName ?? task.storeName}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    subtitle: Text(
                      task.storeAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Chip(
                      label: Text('In-App Route', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      backgroundColor: AppColors.primaryContainer,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      controller.focusPickupTarget();
                      Get.snackbar(
                        'Gebeta Map Updated',
                        'Showing route to ${task.storeName}',
                        backgroundColor: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.onlineGreenBg,
                      child: const Icon(Icons.location_on_rounded, color: AppColors.onlineGreen, size: 20),
                    ),
                    title: Text(
                      'Drop-off: ${task.customerName}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    subtitle: Text(
                      task.customerAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Chip(
                      label: Text('In-App Route', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onlineGreen)),
                      backgroundColor: AppColors.onlineGreenBg,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      controller.focusDropoffTarget();
                      Get.snackbar(
                        'Gebeta Map Updated',
                        'Showing route to ${task.customerName}',
                        backgroundColor: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    },
                  ),

                  const Divider(height: 24),

                  // External Google Maps Section
                  const Text(
                    'EXTERNAL TURN-BY-TURN (GOOGLE MAPS)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _launchNavigationTo(
                              lat: task.storeLatitude,
                              lng: task.storeLongitude,
                              address: '${task.storeName}, ${task.storeAddress}',
                            );
                          },
                          icon: const Icon(Icons.navigation_rounded, size: 16),
                          label: const AutoSizeText(
                            'Maps to Pickup',
                            maxLines: 1,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _launchNavigationTo(
                              lat: task.customerLatitude,
                              lng: task.customerLongitude,
                              address: task.customerAddress,
                            );
                          },
                          icon: const Icon(Icons.navigation_rounded, size: 16),
                          label: const AutoSizeText(
                            'Maps to Drop-off',
                            maxLines: 1,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.onlineGreen,
                            side: const BorderSide(color: AppColors.onlineGreen),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ActiveDeliveryController>();
    if (Get.arguments is DeliveryTask) {
      final passedTask = Get.arguments as DeliveryTask;
      if (controller.currentTask.value?.id != passedTask.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.setActiveTask(passedTask);
        });
      }
    }
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const AutoSizeText(
          'Active Delivery',
          maxLines: 1,
          minFontSize: 14,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation_rounded, color: AppColors.primary),
            tooltip: 'Navigation Destinations',
            onPressed: () => _showNavigationSheet(context, controller.currentTask.value),
          ),
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
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'View Order Details',
            onPressed: () {
              final task = controller.currentTask.value;
              if (task != null) {
                Get.toNamed(Pages.orderDetail, arguments: task);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Support',
            onPressed: () {
              Get.snackbar(
                'Help & Support',
                'Contact dispatch at 8896 or tap SOS.',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),
        ],
      ),
      body: Obx(() {
        final task = controller.currentTask.value;

        if (task == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: AppColors.onlineGreen,
                  ),
                  const SizedBox(height: 16),
                  AutoSizeText(
                    'No Active Delivery',
                    maxLines: 1,
                    minFontSize: 14,
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  AutoSizeText(
                    'Select an assigned delivery to begin navigating.',
                    maxLines: 2,
                    minFontSize: 11,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final isHeadingToStore = task.status != DeliveryStatus.pickedUp;
        final isTargetingPickup = controller.focusedTarget.value == 'pickup' ||
            (controller.focusedTarget.value == null && isHeadingToStore);

        final targetLat = isTargetingPickup ? task.storeLatitude : task.customerLatitude;
        final targetLng = isTargetingPickup ? task.storeLongitude : task.customerLongitude;
        final targetAddress = isTargetingPickup ? '${task.storeName}, ${task.storeAddress}' : task.customerAddress;
        final targetTitle = isTargetingPickup ? (task.propertyName ?? task.storeName) : task.customerName;

        return Stack(
          children: [
            // 1. Map View / Visual Route Layer with in-app Gebeta Maps
            Positioned.fill(
              bottom: MediaQuery.of(context).size.height * 0.46,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DriverMapCanvas(
                    key: ValueKey('${task.id}_${isTargetingPickup ? 'pickup' : 'dropoff'}'),
                    isOnline: true,
                    showRoute: true,
                    dropoffLatitude: targetLat,
                    dropoffLongitude: targetLng,
                    dropoffAddress: targetAddress,
                    onRouteCalculated: (route) {
                      controller.updateGebetaRouteMetrics(route.formattedDistance, route.formattedDuration);
                    },
                  ),
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.transparent,
                            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating Turn-by-Turn Instruction Card (In-app Gebeta Directions HUD + Google Maps launch)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isTargetingPickup ? AppColors.primary : AppColors.onlineGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isTargetingPickup ? Icons.turn_left_rounded : Icons.navigation_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AutoSizeText(
                                  isTargetingPickup
                                      ? 'Heading to $targetTitle'
                                      : 'Delivering to $targetTitle',
                                  maxLines: 1,
                                  minFontSize: 11,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                AutoSizeText(
                                  controller.gebetaRemainingDistance.value.isNotEmpty
                                      ? '${controller.gebetaRemainingDistance.value} remaining • Est. ${controller.gebetaRemainingDuration.value}'
                                      : (isTargetingPickup
                                          ? '${task.storeDistanceKm} km remaining • Est. 4 mins'
                                          : '${task.customerDistanceKm} km remaining • Est. 9 mins'),
                                  maxLines: 1,
                                  minFontSize: 9,
                                  style: textTheme.bodySmall?.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Option A: In-App Gebeta switch route
                          IconButton.filledTonal(
                            onPressed: () {
                              if (isTargetingPickup) {
                                controller.focusDropoffTarget();
                              } else {
                                controller.focusPickupTarget();
                              }
                            },
                            icon: const Icon(Icons.alt_route_rounded, size: 18, color: AppColors.primary),
                            tooltip: isTargetingPickup ? 'Switch to Drop-off Route' : 'Switch to Pickup Route',
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Option B: Google Maps external launch
                          IconButton.filled(
                            onPressed: () => _launchNavigationTo(
                              lat: targetLat,
                              lng: targetLng,
                              address: targetAddress,
                            ),
                            icon: const Icon(Icons.navigation_rounded, size: 18, color: Colors.white),
                            tooltip: 'Open in Google Maps',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Slide-up Workflow Bottom Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                elevation: 8,
                shadowColor: Colors.black26,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.52,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle pill
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Order Number & Payout in ETB (Responsive with Expanded & FittedBox)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AutoSizeText(
                                  'Order #${task.orderNumber}',
                                  maxLines: 1,
                                  minFontSize: 12,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                                AutoSizeText(
                                  task.storeName,
                                  maxLines: 1,
                                  minFontSize: 10,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.onlineGreenBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: AutoSizeText(
                                formatEtb(task.totalPayout),
                                maxLines: 1,
                                minFontSize: 11,
                                style: const TextStyle(
                                  color: AppColors.onlineGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 4-Step Progress Indicator (Accepted, To Shop, To You, Deliverd)
                      Builder(builder: (context) {
                        final int activeStep = task.status == DeliveryStatus.assigned
                            ? 0
                            : (task.status == DeliveryStatus.headingToStore || task.status == DeliveryStatus.atStore
                                ? 1
                                : (task.status == DeliveryStatus.pickedUp ? 2 : 3));

                        return Row(
                          children: [
                            _buildStepIndicator(
                              stepIndex: 0,
                              label: 'Accepted',
                              currentStep: activeStep,
                            ),
                            _buildStepDivider(isActive: activeStep >= 1),
                            _buildStepIndicator(
                              stepIndex: 1,
                              label: 'To Shop',
                              currentStep: activeStep,
                            ),
                            _buildStepDivider(isActive: activeStep >= 2),
                            _buildStepIndicator(
                              stepIndex: 2,
                              label: 'To You',
                              currentStep: activeStep,
                            ),
                            _buildStepDivider(isActive: activeStep >= 3),
                            _buildStepIndicator(
                              stepIndex: 3,
                              label: 'Deliverd',
                              currentStep: activeStep,
                            ),
                          ],
                        );
                      }),

                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // Scrollable Checklist / Customer Info Area
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            if (task.status != DeliveryStatus.pickedUp) ...[
                              // Property / Pickup Details Card
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  AutoSizeText(
                                    task.isCourier
                                        ? 'PICKUP / SENDER DETAILS'
                                        : (task.isCorporate ? 'BRANCH / PICKUP DETAILS' : 'STORE / PROPERTY DETAILS'),
                                    maxLines: 1,
                                    minFontSize: 9,
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => Get.toNamed(Pages.orderDetail, arguments: task),
                                    child: const Text(
                                      'Full Order >',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.outlineVariant),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          task.isCourier
                                              ? Icons.local_shipping_outlined
                                              : (task.isCorporate ? Icons.business_rounded : Icons.storefront_rounded),
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              AutoSizeText(
                                                task.propertyName ?? task.storeName,
                                                maxLines: 1,
                                                style: textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              AutoSizeText(
                                                task.storeAddress,
                                                maxLines: 2,
                                                minFontSize: 9,
                                                style: textTheme.bodySmall?.copyWith(fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton.filledTonal(
                                              icon: const Icon(Icons.map_rounded, size: 18),
                                              color: AppColors.primary,
                                              tooltip: 'In-App Gebeta Route',
                                              onPressed: () {
                                                controller.focusPickupTarget();
                                                Get.snackbar(
                                                  'Gebeta Map',
                                                  'Showing in-app route to ${task.storeName}',
                                                  backgroundColor: Colors.white,
                                                  duration: const Duration(seconds: 2),
                                                );
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
                                    if (task.deliveryNotes != null && task.deliveryNotes!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.warningAmberBg,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warningAmber),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                task.deliveryNotes!,
                                                style: textTheme.bodySmall?.copyWith(
                                                  color: AppColors.onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (task.items.isNotEmpty) ...[
                                // Items Verification Checklist
                                AutoSizeText(
                                  'COLLECT & VERIFY ITEMS (${task.items.length})',
                                  maxLines: 1,
                                  minFontSize: 9,
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...task.items.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  return CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: AppColors.primary,
                                    value: item.isChecked,
                                    onChanged: (_) => controller.toggleItem(index),
                                    title: AutoSizeText(
                                      '${item.quantity}x ${item.name}',
                                      maxLines: 1,
                                      minFontSize: 10,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontSize: 12.5,
                                        decoration: item.isChecked
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        color: item.isChecked
                                            ? AppColors.onSurfaceVariant
                                            : AppColors.onSurface,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ] else ...[
                              // Customer Dropoff Details
                              Text(
                                task.isCourier
                                    ? 'RECIPIENT INFORMATION'
                                    : (task.isCorporate ? 'DESTINATION BRANCH / RECIPIENT' : 'CUSTOMER INFORMATION'),
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
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
                                          task.customerAddress,
                                          maxLines: 2,
                                          minFontSize: 9,
                                          style: textTheme.bodySmall?.copyWith(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton.filledTonal(
                                        icon: const Icon(Icons.map_rounded,
                                            size: 18, color: AppColors.onlineGreen),
                                        tooltip: 'In-App Gebeta Route',
                                        onPressed: () {
                                          controller.focusDropoffTarget();
                                          Get.snackbar(
                                            'Gebeta Map',
                                            'Showing in-app route to ${task.customerName}',
                                            backgroundColor: Colors.white,
                                            duration: const Duration(seconds: 2),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton.filledTonal(
                                        icon: const Icon(Icons.navigation_rounded,
                                            size: 18, color: AppColors.primary),
                                        tooltip: 'Google Maps Directions',
                                        onPressed: () => _launchNavigationTo(
                                          lat: task.customerLatitude,
                                          lng: task.customerLongitude,
                                          address: task.customerAddress,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton.filledTonal(
                                        icon: const Icon(Icons.phone_rounded,
                                            size: 18, color: AppColors.primary),
                                        tooltip: 'Call Customer',
                                        onPressed: () => _makePhoneCall(task.customerPhone),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton.filledTonal(
                                        icon: const Icon(Icons.sms_outlined,
                                            size: 18, color: AppColors.primary),
                                        tooltip: 'SMS Customer',
                                        onPressed: () => _sendSms(task.customerPhone),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (task.deliveryNotes != null && task.deliveryNotes!.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningAmberBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded,
                                          size: 16, color: AppColors.warningAmber),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Note: ${task.deliveryNotes!}',
                                          style: textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Step Action Button aligned with Statuses: 1: Accepted, 2: To Shop, 3: To You, 4: Deliverd
                      if (task.status == DeliveryStatus.assigned)
                        _buildDeliveryActionButton(
                          buttonKey: const Key('btn_driver_on_way_to_shop'),
                          label: 'Start Driving to Store',
                          icon: Icons.directions_car_rounded,
                          backgroundColor: AppColors.primary,
                          onPressed: controller.startDriverOnTheWayToShop,
                        )
                      else if (task.status == DeliveryStatus.headingToStore || task.status == DeliveryStatus.atStore)
                        _buildDeliveryActionButton(
                          buttonKey: const Key('btn_confirm_pickup_depart'),
                          label: 'Confirm Pickup & Depart',
                          icon: Icons.inventory_2_rounded,
                          backgroundColor: AppColors.primary,
                          onPressed: controller.confirmPickupAndDepart,
                        )
                      else if (task.status == DeliveryStatus.pickedUp)
                        _buildDeliveryActionButton(
                          buttonKey: const Key('btn_complete_delivery'),
                          label: 'Complete Delivery',
                          icon: Icons.check_circle_rounded,
                          backgroundColor: AppColors.onlineGreen,
                          onPressed: controller.completeDelivery,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildStepIndicator({
    required int stepIndex,
    required String label,
    required int currentStep,
  }) {
    final isDone = currentStep > stepIndex;
    final isCurrent = currentStep == stepIndex;

    Color bg;
    Widget icon;

    if (isDone) {
      bg = AppColors.onlineGreen;
      icon = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isCurrent) {
      bg = AppColors.primary;
      icon = Text(
        '${stepIndex + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      bg = AppColors.outlineVariant;
      icon = Text(
        '${stepIndex + 1}',
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: bg,
          child: icon,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        color: isActive ? AppColors.onlineGreen : AppColors.outlineVariant,
      ),
    );
  }

  Widget _buildDeliveryActionButton({
    required Key buttonKey,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: backgroundColor.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
