import 'package:get/get.dart';
import '../controllers/active_delivery_controller.dart';
import '../controllers/deliveries_controller.dart';
import '../controllers/driver_dashboard_controller.dart';
import '../controllers/earnings_controller.dart';
import '../controllers/history_controller.dart';
import '../controllers/profile_controller.dart';
import '../core/theme/theme_controller.dart';
import '../screens/main_driver_navigation.dart';

import '../controllers/driver_auth_controller.dart';
import '../services/driver_battery_service.dart';
import '../services/driver_location_update_service.dart';
import '../services/driver_socket_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ThemeController>(ThemeController(), permanent: true);
    Get.put<DriverBatteryService>(DriverBatteryService(), permanent: true);
    Get.put<DriverLocationUpdateService>(DriverLocationUpdateService(), permanent: true);
    Get.put<DriverSocketService>(DriverSocketService(), permanent: true);
    Get.put<DriverAuthController>(DriverAuthController(), permanent: true);
    Get.put<ActiveDeliveryController>(ActiveDeliveryController(), permanent: true);
    Get.put<EarningsController>(EarningsController(), permanent: true);
    Get.put<DeliveriesController>(DeliveriesController(), permanent: true);
    Get.put<HistoryController>(HistoryController(), permanent: true);
    Get.put<DriverDashboardController>(DriverDashboardController(), permanent: true);
    Get.put<ProfileController>(ProfileController(), permanent: true);
    Get.put<MainDriverNavigationController>(MainDriverNavigationController(), permanent: true);
  }
}
