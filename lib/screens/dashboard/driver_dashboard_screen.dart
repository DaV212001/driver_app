import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/pages.dart';
import '../../controllers/driver_dashboard_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../services/driver_location_update_service.dart';
import 'widgets/bottom_performance_card.dart';
import 'widgets/driver_app_drawer.dart';
import 'widgets/driver_map_canvas.dart';
import 'widgets/incoming_job_offer_sheet.dart';
import 'widgets/street_pickup_bottom_sheet.dart';

class DriverDashboardScreen extends StatelessWidget {
  const DriverDashboardScreen({super.key});

  void _openStreetPickupSheet(BuildContext context, DriverDashboardController controller) {
    if (controller.hasActiveAcceptedOrder) {
      Get.snackbar(
        'Delivery in Progress 🔒',
        'Please complete your active delivery before creating a new order.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF1E293B),
        colorText: Colors.white,
      );
      return;
    }

    double? currentLat;
    double? currentLng;
    if (Get.isRegistered<DriverLocationUpdateService>()) {
      currentLat = DriverLocationUpdateService.to.lastLatitude.value;
      currentLng = DriverLocationUpdateService.to.lastLongitude.value;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StreetPickupBottomSheet(
        initialFromLatitude: currentLat,
        initialFromLongitude: currentLng,
        onCreateOrder: ({
          required String pickupAddress,
          required String destinationAddress,
          required String serviceCategory,
          required String customerPhone,
          double? fromLatitude,
          double? fromLongitude,
          double? toLatitude,
          double? toLongitude,
          int? carTypeId,
          double? kmPrice,
          double? totalPrice,
          String? description,
          String? fromFriendlyLocation,
          String? toFriendlyLocation,
        }) {
          controller.createStreetPickupOrder(
            pickupAddress: pickupAddress,
            destinationAddress: destinationAddress,
            serviceCategory: serviceCategory,
            customerPhone: customerPhone,
            fromLatitude: fromLatitude,
            fromLongitude: fromLongitude,
            toLatitude: toLatitude,
            toLongitude: toLongitude,
            carTypeId: carTypeId,
            kmPrice: kmPrice,
            totalPrice: totalPrice,
            description: description,
            fromFriendlyLocation: fromFriendlyLocation,
            toFriendlyLocation: toFriendlyLocation,
          );
        },
      ),
    );
  }

  Future<void> _callEmergency(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Assistance 🚨'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tap any contact to call immediately:'),
            const SizedBox(height: 12),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 28),
              title: const Text(
                'AMN Emergency Hotline: 8896',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('24/7 Driver Safety & Dispatch (Short Code)'),
              trailing: const Icon(Icons.call_rounded, color: AppColors.primary),
              onTap: () => _callEmergency('8896'),
            ),
            const Divider(height: 16),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_police_rounded, color: Colors.blue),
              title: const Text('Addis Ababa Police: 991'),
              trailing: const Icon(Icons.call_rounded, color: Colors.blue),
              onTap: () => _callEmergency('991'),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.medical_services_rounded, color: Colors.red),
              title: const Text('Emergency Ambulance: 907'),
              trailing: const Icon(Icons.call_rounded, color: Colors.red),
              onTap: () => _callEmergency('907'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _openNotificationsSheet(BuildContext context, DriverDashboardController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dispatch Alerts 🔔',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              const ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bolt_rounded, color: AppColors.primary),
                title: Text('High Demand Surge in Bole Area'),
                subtitle: Text('Fares are currently 1.5x on Airport Road.'),
              ),
              const Divider(),
              const ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.star_rounded, color: AppColors.starGold),
                title: Text('Weekly Bonus Active'),
                subtitle: Text('Complete 35 trips this week for ETB 5,000 bonus.'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    controller.triggerIncomingOffer();
                  },
                  icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Simulate Incoming Job Offer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DriverDashboardController>();
    final themeCtrl = Get.find<ThemeController>();
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: Obx(() => DriverAppDrawer(profile: controller.profile.value)),
      body: Stack(
        children: [
          // 1. Fullscreen Interactive Map Canvas & Road Network
          Obx(() {
            final offer = controller.incomingOffer.value;
            final hasOffer = offer != null;
            final isOnline = controller.isOnline.value;

            return DriverMapCanvas(
              isOnline: isOnline,
              showRoute: hasOffer,
              pickupLatitude: offer?.pickupLatitude,
              pickupLongitude: offer?.pickupLongitude,
              dropoffLatitude: offer?.dropoffLatitude,
              dropoffLongitude: offer?.dropoffLongitude,
              pickupAddress: offer?.pickupName,
              dropoffAddress: offer?.dropoffName,
              onToggleOnline: controller.toggleOnlineStatus,
              onOpenNotifications: () => _openNotificationsSheet(context, controller),
              onOpenSos: () => _showEmergencyDialog(context),
              onOpenDestinations: () => _openStreetPickupSheet(context, controller),
            );
          }),

          // 2. Custom Top Navigation Bar (Hamburger Menu & Online/Offline Switch)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Obx(() {
                        final isDark = themeCtrl.isDarkMode;
                        final overlayBg = isDark
                            ? const Color(0xFF111827).withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.95);
                        final overlayBorder = isDark ? AppColors.darkOutline : AppColors.outline;
                        final overlayShadow = isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: 0.08);
                        final iconColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
                        final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
                        final isOnline = controller.isOnline.value;
                        final isUpdating = controller.isUpdatingOnline.value;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left Side: Circular Hamburger Menu Button
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: overlayBg,
                                border: Border.all(color: overlayBorder, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: overlayShadow,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => scaffoldKey.currentState?.openDrawer(),
                                  child: Center(
                                    child: Icon(Icons.menu_rounded, color: iconColor, size: 26),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Right Side: Online / Offline Switch + Theme toggle
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Online / Offline Switch Pill
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: isUpdating ? null : controller.toggleOnlineStatus,
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: overlayBg,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: isOnline ? AppColors.onlineGreen : overlayBorder,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isOnline
                                                ? AppColors.onlineGreen.withValues(alpha: 0.25)
                                                : overlayShadow,
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isOnline ? 'Online' : 'Offline',
                                            style: TextStyle(
                                              color: isOnline ? AppColors.onlineGreen : textColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 250),
                                            width: 44,
                                            height: 26,
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(13),
                                              color: isOnline
                                                  ? AppColors.onlineGreen
                                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                            ),
                                            child: AnimatedAlign(
                                              duration: const Duration(milliseconds: 250),
                                              alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
                                              child: Container(
                                                width: 22,
                                                height: 22,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black26,
                                                      blurRadius: 4,
                                                      offset: Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Theme Toggle Button
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: overlayBg,
                                    border: Border.all(color: overlayBorder, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: overlayShadow,
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: themeCtrl.toggleTheme,
                                      child: Center(
                                        child: Icon(
                                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                          size: 22,
                                          color: isDark ? AppColors.starGold : AppColors.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Bottom Overlays (Incoming Job Offer Sheet OR Bottom Performance Card)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Obx(() {
              final offer = controller.incomingOffer.value;

              if (offer != null) {
                // Incoming Job Offer Sheet (Photo 4)
                return IncomingJobOfferSheet(
                  offer: offer,
                  remainingSeconds: controller.offerRemainingSeconds.value,
                  onAccept: controller.acceptIncomingOffer,
                  onDismiss: controller.dismissIncomingOffer,
                );
              }

              // Standard Bottom Performance Card (Photo 1) with Active Order quick-resume pill
              final active = controller.activeDelivery;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => controller.startOrResumeDelivery(active),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Active Order #${active.orderNumber} • ${active.statusLabel}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Tap to continue navigation & update status',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  BottomPerformanceCard(
                    todayEarnings: controller.todayEarnings.value,
                    walletBalance: controller.walletBalance.value,
                    profileScore: controller.profileScore.value,
                    rating: controller.driverRating.value,
                    cancellationRate: controller.cancellationRate.value,
                    onWalletTap: () => Get.toNamed(Pages.wallet),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
