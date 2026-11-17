import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/storage_config.dart';
import '../../../constants/pages.dart';
import '../../../controllers/driver_dashboard_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/driver_profile.dart';
import '../../../services/driver_battery_service.dart';

class DriverAppDrawer extends StatelessWidget {
  final DriverProfile profile;

  const DriverAppDrawer({
    super.key,
    required this.profile,
  });



  Future<void> _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }

  Future<void> _launchCustomerAppDownload() async {
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.amn.delivery_app';
    const marketUri = 'market://details?id=com.amn.delivery_app';

    try {
      final marketUriParsed = Uri.parse(marketUri);
      if (await canLaunchUrl(marketUriParsed)) {
        await launchUrl(marketUriParsed, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final webUri = Uri.parse(playStoreUrl);
      final launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      Get.snackbar(
        'AMN App',
        'Could not open Google Play Store. Search "AMN Delivery" on Play Store.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E293B),
        colorText: Colors.white,
      );
    }
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
              onTap: () => _callNumber('8896'),
            ),
            const Divider(height: 16),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_police_rounded, color: Colors.blue),
              title: const Text('Addis Ababa Police: 991'),
              trailing: const Icon(Icons.call_rounded, color: Colors.blue),
              onTap: () => _callNumber('991'),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.medical_services_rounded, color: Colors.red),
              title: const Text('Emergency Ambulance: 907'),
              trailing: const Icon(Icons.call_rounded, color: Colors.red),
              onTap: () => _callNumber('907'),
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

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support 🎧'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need help with dispatch, payments, or your account?'),
            const SizedBox(height: 12),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_in_talk_rounded, color: AppColors.primary),
              title: const Text(
                'Phone Hotline: 8896',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('24/7 Toll-free Short Code'),
              trailing: const Icon(Icons.call_rounded, color: AppColors.primary),
              onTap: () => _callNumber('8896'),
            ),
            const Divider(height: 16),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined, color: AppColors.primary),
              title: const Text(
                'info@amnplc.com',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Official Support Email'),
              trailing: const Icon(Icons.mail_outline_rounded, color: AppColors.primary),
              onTap: () => _sendEmail('info@amnplc.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, DriverProfile activeProfile) {
    final displayName = activeProfile.name.isNotEmpty
        ? activeProfile.name
        : (StorageConfig.getDriverName()?.isNotEmpty == true
            ? StorageConfig.getDriverName()!
            : 'Driver');

    final avatar = activeProfile.avatarUrl.isNotEmpty
        ? activeProfile.avatarUrl
        : (StorageConfig.getDriverAvatar() ?? '');

    final vehicleName = activeProfile.vehicle.type.isNotEmpty
        ? activeProfile.vehicle.type
        : (StorageConfig.getDriverVehicleName() ?? '');

    final plateNumber = activeProfile.vehicle.plateNumber.isNotEmpty
        ? activeProfile.vehicle.plateNumber
        : (StorageConfig.getDriverPlateNumber() ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF0077AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            backgroundColor: Colors.white24,
            child: avatar.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (vehicleName.isNotEmpty || plateNumber.isNotEmpty) ...[
                  Text(
                    [vehicleName, plateNumber].where((s) => s.isNotEmpty).join(' • '),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Get.toNamed(Pages.profile);
                  },
                  child: const Text(
                    'View Profile',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Drawer(
      backgroundColor: drawerBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Profile Header in AMN Primary Blue (Photo 5)
            if (Get.isRegistered<ProfileController>())
              Obx(() => _buildProfileHeader(context, Get.find<ProfileController>().profile.value))
            else if (Get.isRegistered<DriverDashboardController>())
              Obx(() => _buildProfileHeader(context, Get.find<DriverDashboardController>().profile.value))
            else
              _buildProfileHeader(context, profile),

            // 2. Navigation Items (Photo 5)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Live Dispatch Battery Validation Status
                  if (Get.isRegistered<DriverBatteryService>())
                    Obx(() {
                      final batteryService = DriverBatteryService.to;
                      final percent = batteryService.batteryPercent.value;
                      final isReporting = batteryService.isReporting.value;
                      final lastSent = batteryService.lastSentAt.value;
                      final timeStr = lastSent != null ? DateFormat('hh:mm a').format(lastSent.toLocal()) : 'Pending';

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: percent <= 20
                                ? AppColors.secondary.withValues(alpha: 0.5)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              percent <= 20
                                  ? Icons.battery_alert_rounded
                                  : (percent <= 50 ? Icons.battery_4_bar_rounded : Icons.battery_full_rounded),
                              color: percent <= 20
                                  ? AppColors.secondary
                                  : (percent <= 50 ? Colors.orange : AppColors.onlineGreen),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Battery: $percent%',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    isReporting ? 'Reporting to dispatch...' : 'Synced: $timeStr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: isReporting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    )
                                  : const Icon(Icons.sync_rounded, size: 18, color: AppColors.primary),
                              tooltip: 'Sync Battery',
                              onPressed: isReporting
                                  ? null
                                  : () => batteryService.sendBatteryPercent(reason: 'drawer_manual_sync'),
                            ),
                          ],
                        ),
                      );
                    }),
                  // _DrawerTile(
                  //   icon: Icons.toll_rounded,
                  //   label: 'AMN Miles',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     if (Get.isRegistered<EarningsController>()) {
                  //       Get.find<EarningsController>().fetchWalletAndEarnings();
                  //     }
                  //     Get.toNamed(Pages.earnings);
                  //   },
                  // ),
                  _DrawerTile(
                    icon: Icons.directions_car_rounded,
                    label: 'Services',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(Pages.services);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(Pages.wallet);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.history_rounded,
                    label: 'Trip history',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(Pages.deliveryHistory);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Get.toNamed(Pages.profile);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.emergency_outlined,
                    label: 'Emergency Contacts',
                    onTap: () => _showEmergencyDialog(context),
                  ),
                  _DrawerTile(
                    icon: Icons.headset_mic_outlined,
                    label: 'Contact us',
                    onTap: () => _showContactDialog(context),
                  ),
                ],
              ),
            ),

            // 3. Bottom Download AMN App Promo Card (Photo 5)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _launchCustomerAppDownload,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Download AMN App',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Need to book a trip? Tap to get AMN',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    );
  }
}
