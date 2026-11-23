import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/storage_config.dart';
import '../controllers/earnings_controller.dart';
import '../services/notification_service.dart';
import 'dashboard/driver_dashboard_screen.dart';
import 'earnings/earnings_screen.dart';
import 'profile/driver_profile_screen.dart';
import 'active_delivery/active_delivery_screen.dart';

class MainDriverNavigationController extends GetxController {
  final RxInt selectedIndex = 0.obs;

  void setIndex(int index) {
    if (StorageConfig.hasActiveOrder()) {
      final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
      if (!inTest) {
        Get.snackbar(
          'Order in Progress 🔒',
          'Please complete your active delivery before navigating away.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF1E293B),
          colorText: Colors.white,
        );
      }
      return;
    }
    selectedIndex.value = index;
    if (index == 1 && Get.isRegistered<EarningsController>()) {
      Get.find<EarningsController>().fetchWalletAndEarnings();
    }
  }

  void returnToDashboard() {
    selectedIndex.value = 0;
  }
}

class MainDriverNavigation extends StatelessWidget {
  const MainDriverNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final navCtrl = Get.put(MainDriverNavigationController());

    final List<Widget> screens = [
      const DriverDashboardScreen(),
      EarningsScreen(onBack: navCtrl.returnToDashboard),
      const ActiveDeliveryScreen(),
      DriverProfileScreen(onBack: navCtrl.returnToDashboard),
    ];

    return Scaffold(
      body: Obx(() => IndexedStack(
            index: navCtrl.selectedIndex.value,
            children: screens,
          )),
    );
  }
}
