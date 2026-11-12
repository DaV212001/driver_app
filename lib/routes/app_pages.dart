import 'package:get/get.dart';
import '../config/storage_config.dart';
import '../constants/pages.dart';
import '../screens/dashboard/driver_dashboard_screen.dart';
import '../screens/deliveries/assigned_deliveries_screen.dart';
import '../screens/active_delivery/active_delivery_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/history/delivery_history_screen.dart';
import '../screens/earnings/earnings_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../screens/wallet/wallet_deposit_screen.dart';
import '../screens/wallet/wallet_transfer_screen.dart';
import '../screens/wallet/payment_webview_screen.dart';
import '../screens/services/services_screen.dart';
import '../screens/orders/trip_detail_screen.dart';
import '../screens/profile/driver_profile_screen.dart';
import '../screens/main_driver_navigation.dart';
import '../screens/auth/driver_login_screen.dart';
import '../screens/auth/driver_otp_screen.dart';
import '../screens/auth/driver_forgot_password_screen.dart';
import 'auth_middleware.dart';

class AppPages {
  /// Only allow access to main pages if the user is logged in
  static String get initial {
    if (!StorageConfig.isLoggedIn()) return Pages.login;
    if (StorageConfig.hasActiveOrder()) return Pages.orderDetail;
    return Pages.mainNavigation;
  }

  static final routes = [
    GetPage(
      name: Pages.mainNavigation,
      page: () => const MainDriverNavigation(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.login,
      page: () => const DriverLoginScreen(),
    ),
    GetPage(
      name: Pages.otp,
      page: () => const DriverOtpScreen(),
    ),
    GetPage(
      name: Pages.forgotPassword,
      page: () => const DriverForgotPasswordScreen(),
    ),
    GetPage(
      name: Pages.dashboard,
      page: () => const DriverDashboardScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.assignedDeliveries,
      page: () => const AssignedDeliveriesScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.activeDelivery,
      page: () => const ActiveDeliveryScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.orderDetail,
      page: () => const OrderDetailScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.deliveryHistory,
      page: () => const DeliveryHistoryScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.earnings,
      page: () => const EarningsScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.wallet,
      page: () => const WalletScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.walletDeposit,
      page: () => const WalletDepositScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.walletTransfer,
      page: () => const WalletTransferScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.paymentWebView,
      page: () => PaymentWebViewScreen(
        initialUrl: Get.arguments is Map ? (Get.arguments['url'] ?? '') : (Get.arguments?.toString() ?? ''),
        title: Get.arguments is Map ? (Get.arguments['title'] ?? 'Chapa Checkout') : 'Chapa Checkout',
      ),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.services,
      page: () => const ServicesScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.tripDetail,
      page: () => const TripDetailScreen(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Pages.profile,
      page: () => const DriverProfileScreen(),
      middlewares: [AuthMiddleware()],
    ),
  ];
}
