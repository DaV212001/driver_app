class ApiEndpoints {
  // Driver Auth endpoints (from Auth.postman_collection.json)
  static const String driverLogin = '/driver-login';
  static const String driverRegister = '/driver-register';
  static const String driverForgetPassword = '/driver-forget-password';
  static const String driverSendOtp = '/driver-send-otp';
  static const String driverVerifyOtp = '/driver-verify-otp';
  static const String driverChangePassword = '/driver-change-password';
  static const String driverLogout = '/driver-logout';
  static const String driverChangeProfileImage = '/driver-change-profile-image';

  // Customer Auth endpoints (for reference)
  static const String customerLogin = '/customer-login';
  static const String customerRegister = '/customer-register';
  static const String customerForgetPassword = '/customer-forget-password';
  static const String customerSendOtp = '/customer-send-otp';
  static const String customerVerifyOtp = '/customer-verify-otp';
  static const String customerChangePassword = '/customer-change-password';
  static const String customerLogout = '/customer-logout';
  static const String customerChangeProfileImage = '/customer-change-profile-image';

  // Orders endpoints (from Order.postman_collection.json)
  static const String order = '/order';
  static String activeOrders(dynamic id) => '/my_active_order/$id';
  static String pastOrders(dynamic id) => '/my_past_order/$id';
  static String orderDetail(dynamic orderId) => '/my_order_detail/$orderId';
  static String courierOrderDetail(dynamic orderId) => '/courirer-order/$orderId';
  static String corporateOrderDetail(dynamic orderId) => '/company-order/$orderId';
  static String acceptOrder(dynamic orderId) => '/orders/$orderId/accept-order';
  static String updateStandardOrder(dynamic orderId) => '/orders/$orderId/update-order';
  static const String pickupOrder = '/pickup-order';
  static String updatePickupOrder(dynamic orderId) => '/pickup-order/$orderId/update-order';
  static const String courierOrder = '/courirer-order';
  static String updateCourierOrder(dynamic orderId) => '/courirer-order/$orderId/update-order';
  static const String corporateOrder = '/corporate-order';
  static String updateCorporateOrder(dynamic orderId) => '/corporate-order/$orderId/update-order';

  // Driver Order History endpoints (from Driver postman collection)
  static String driverOrderHistory(String startDate, String endDate, dynamic driverId) =>
      '/driver-order-history/$startDate/$endDate/$driverId';
  static String driverCompanyOrderHistory(String startDate, String endDate, dynamic driverId) =>
      '/driver-company-order-history/$startDate/$endDate/$driverId';
  static String driverPickupOrderHistory(String startDate, String endDate, dynamic driverId) =>
      '/driver-pickup-order-history/$startDate/$endDate/$driverId';

  // Profile & Wallet endpoints
  static String driverProfile(dynamic id) => '/driver-profile/$id';
  static String profile(dynamic id) => '/driver-profile/$id';
  static String walletAmount(dynamic id) => '/driver_my_wallet_amount/$id';
  static String driverWalletAmount(dynamic id) => '/driver_my_wallet_amount/$id';
  static const String driverWalletPayment = '/driver-wallet-payment';
  static String driverWalletPaymentCallback(String reference, dynamic userId) =>
      '/driver-wallet-payment-callback/$reference/$userId';
  static String todayEarning(dynamic id) => '/today_earning/$id';
  static String customerWalletAmount(dynamic id) => '/my_wallet_amount/$id';
  static String walletTransactions(dynamic id) => '/my_wallet_transaction/$id';
  static String updateOnline(dynamic driverId) => '/driver/$driverId/update-online';

  // Battery percentage validation endpoint (from Driver postman collection)
  static const String driverBatteryPercent = '/driver-battry-percent';

  // Driver continuous location tracking endpoint
  static const String driverLocation = '/driver-location';

  // Information endpoints (from Information.postman_collection.json)
  static const String privacy = '/privacy';
  static const String termsAndConditions = '/term_and_condition';
  static const String faq = '/faq';

  // Vehicle & City Metadata endpoints
  static const String vehicleType = '/vehicle-type';
  static const String city = '/city';
  static String deliveryPriceByCarAndCity(dynamic vehicleId, dynamic cityId) =>
      '/delivery-price-by-car-and-city-id/$vehicleId/$cityId';
}
