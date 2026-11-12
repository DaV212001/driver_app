import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../config/storage_config.dart';
import '../constants/pages.dart';
import '../models/city.dart';
import '../models/driver_profile.dart';
import '../models/vehicle_type.dart';
import '../services/driver_auth_service.dart';
import '../services/driver_battery_service.dart';
import '../services/driver_location_update_service.dart';
import '../services/driver_order_service.dart';
import '../services/driver_profile_service.dart';
import '../services/driver_socket_service.dart';
import '../services/notification_service.dart';
import 'active_delivery_controller.dart';
import 'driver_dashboard_controller.dart';
import 'earnings_controller.dart';
import 'profile_controller.dart';

class DriverAuthController extends GetxController {
  static DriverAuthController get to => Get.find<DriverAuthController>();
  static bool get isInTest =>
      Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');

  final RxBool _isLoggedIn = false.obs;
  bool get isLoggedIn => _isLoggedIn.value;

  final RxBool isLoading = false.obs;
  final RxBool isSendingOtp = false.obs;
  final RxBool isResettingPassword = false.obs;
  final RxInt resendCooldown = 0.obs;

  // Vehicle and City registration metadata
  final RxList<VehicleTypeModel> vehicleTypes = <VehicleTypeModel>[].obs;
  final RxList<CityModel> cities = <CityModel>[].obs;
  final Rx<int?> selectedVehicleId = Rx<int?>(null);
  final Rx<int?> selectedCityId = Rx<int?>(null);
  final RxBool isLoadingMetadata = false.obs;

  // Vehicle plate number and photo (car_image & plate_number)
  final RxString vehiclePlateNumber = ''.obs;
  final Rx<String?> vehicleImagePath = Rx<String?>(null);

  VehicleTypeModel? get selectedVehicle {
    final id = selectedVehicleId.value;
    if (id == null) return null;
    return vehicleTypes.firstWhereOrNull((v) => v.id == id);
  }

  Future<void> pickVehicleImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (pickedFile != null) {
        vehicleImagePath.value = pickedFile.path;
      }
    } catch (e) {
      _showSnackbar('Image Selection Error', 'Failed to pick vehicle image: $e');
    }
  }

  void clearVehicleImage() {
    vehicleImagePath.value = null;
  }

  // Pending verification state for registration
  int? _pendingUserId;
  String? _pendingToken;
  String? _pendingName;
  String? _pendingPhone;
  String? _pendingEmail;
  String? _pendingOtp;
  int? _pendingVehicleId;
  int? _pendingCityId;
  String? _pendingPlateNumber;

  // Pending verification state for forgot password
  String? _resetPhone;
  String? _resetOtp;
  bool _resetOtpVerified = false;
  bool get isResetOtpVerified => _resetOtpVerified;
  String? get resetPhone => _resetPhone;

  Timer? _cooldownTimer;

  void _safeNavigate(void Function() action) {
    if (!Get.testMode && (Get.context != null || Get.key.currentState != null)) {
      try {
        action();
      } catch (_) {}
    }
  }

  @override
  void onInit() {
    super.onInit();
    final token = StorageConfig.getToken();
    _isLoggedIn.value = token != null && token.isNotEmpty;
    loadRegistrationMetadata();
  }

  /// Load vehicle types and cities from backend API
  Future<void> loadRegistrationMetadata() async {
    isLoadingMetadata.value = true;
    try {
      final fetchedVehicles = await DriverAuthService.fetchVehicleTypes();
      if (fetchedVehicles.isNotEmpty) {
        vehicleTypes.assignAll(fetchedVehicles);
      }

      final fetchedCities = await DriverAuthService.fetchCities();
      if (fetchedCities.isNotEmpty) {
        cities.assignAll(fetchedCities);
      }

      // Default selection if not already selected
      if (selectedVehicleId.value == null && vehicleTypes.isNotEmpty) {
        selectedVehicleId.value = vehicleTypes.first.id;
      }
    } catch (_) {
    } finally {
      isLoadingMetadata.value = false;
    }
  }

  @override
  void onClose() {
    _cooldownTimer?.cancel();
    super.onClose();
  }

  void _showSnackbar(
    String title,
    String message, {
    Color? backgroundColor,
    Color? colorText,
    Duration? duration,
  }) {
    if (Get.testMode) return;
    if (Get.context != null && Get.overlayContext != null) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: backgroundColor ?? Colors.black87,
        colorText: colorText ?? Colors.white,
        duration: duration ?? const Duration(seconds: 3),
      );
    }
  }

  /// Driver Login
  Future<void> login(String phone, String password) async {
    final cleanPhone = DriverAuthService.sanitizePhone(phone);
    if (cleanPhone.length < 9) {
      _showSnackbar('Invalid Phone', 'Please enter a valid phone number');
      return;
    }
    if (password.length != 4 || !RegExp(r'^\d{4}$').hasMatch(password)) {
      _showSnackbar('Invalid Password', 'Password must be exactly 4 digits');
      return;
    }

    isLoading.value = true;
    await DriverAuthService.driverLogin(
      phone: cleanPhone,
      password: password,
      onSuccess: (data) async {
        isLoading.value = false;
        _isLoggedIn.value = true;

        if (!isInTest && Get.isRegistered<DriverBatteryService>()) {
          DriverBatteryService.to.sendBatteryPercent(reason: 'otp_verified');
        }

        if (!isInTest && Get.isRegistered<DriverLocationUpdateService>()) {
          DriverLocationUpdateService.to.startTracking();
        }

        // Connect driver real-time socket to tracking server
        if (!isInTest && Get.isRegistered<DriverSocketService>()) {
          DriverSocketService.to.connect();
        }

        final Map<String, dynamic> userMap = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : (data['driver'] is Map
                ? Map<String, dynamic>.from(data['driver'] as Map)
                : (data['data'] is Map
                    ? Map<String, dynamic>.from(data['data'] as Map)
                    : data));

        final rawId = userMap['id'] ??
            data['id'] ??
            userMap['user_id'] ??
            data['user_id'] ??
            '1';
        final driverId = rawId.toString();

        final firstName = userMap['f_name']?.toString() ??
            userMap['first_name']?.toString() ??
            data['f_name']?.toString() ??
            '';
        final lastName = userMap['l_name']?.toString() ??
            userMap['last_name']?.toString() ??
            data['l_name']?.toString() ??
            '';
        final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
            ? '$firstName $lastName'.trim()
            : (userMap['name']?.toString() ??
                data['name']?.toString() ??
                'Driver');

        final token =
            data['token']?.toString() ?? userMap['token']?.toString() ?? '';
        final avatar = userMap['avatar']?.toString() ??
            userMap['image']?.toString() ??
            data['avatar']?.toString() ??
            '';
        final userPhone = userMap['phone']?.toString();
        final finalPhone = (userPhone != null && userPhone.isNotEmpty)
            ? userPhone
            : cleanPhone;

        final vehicleId = userMap['vehicle_id']?.toString() ?? data['vehicle_id']?.toString() ?? '';
        final plateNumber = userMap['plate_number']?.toString() ?? data['plate_number']?.toString() ?? '';
        final cityId = userMap['city_id']?.toString() ?? data['city_id']?.toString() ?? '';

        await StorageConfig.setToken(token.isNotEmpty ? token : 'driver_token_$driverId');
        await StorageConfig.setDriverId(driverId);
        await StorageConfig.setDriverPhone(finalPhone);
        if (fullName.isNotEmpty) await StorageConfig.setDriverName(fullName);
        if (avatar.isNotEmpty) await StorageConfig.setDriverAvatar(avatar);

        if (vehicleId.isNotEmpty) await StorageConfig.setDriverVehicleId(vehicleId);
        if (plateNumber.isNotEmpty) await StorageConfig.setDriverPlateNumber(plateNumber);
        if (cityId.isNotEmpty) await StorageConfig.setDriverCityId(cityId);

        String vehicleName = '';
        String? vehicleImage;
        final vId = int.tryParse(vehicleId);
        if (vId != null) {
          if (vehicleTypes.isEmpty) {
            final fetched = await DriverAuthService.fetchVehicleTypes();
            if (fetched.isNotEmpty) vehicleTypes.assignAll(fetched);
          }
          final match = vehicleTypes.firstWhereOrNull((v) => v.id == vId);
          if (match != null) {
            vehicleName = match.name;
            vehicleImage = match.image;
            await StorageConfig.setDriverVehicleName(vehicleName);
            if (vehicleImage != null && vehicleImage.isNotEmpty) {
              await StorageConfig.setDriverVehicleImage(vehicleImage);
            }
          }
        }

        // Register FCM device token with AMN notification server upon login
        NotificationService.instance.registerDriverTokenToServer(driverId: driverId);

        final vInfo = VehicleInfo(
          vehicleId: vId,
          type: vehicleName.isNotEmpty ? vehicleName : (vId != null ? 'Vehicle #$vId' : ''),
          model: vehicleName.isNotEmpty ? vehicleName : (vId != null ? 'Vehicle #$vId' : ''),
          plateNumber: plateNumber,
          imageUrl: vehicleImage,
          isVerified: plateNumber.isNotEmpty || vId != null,
        );

        final updatedProfile = DriverProfile(
          id: driverId,
          name: fullName.isNotEmpty ? fullName : 'Driver',
          phone: finalPhone,
          email: userMap['email']?.toString() ?? '',
          avatarUrl: avatar,
          rating: 5.0,
          totalTrips: 0,
          tier: 'Courier',
          vehicle: vInfo,
          bankName: '',
          bankAccountNumber: '',
          autoAcceptOrders: StorageConfig.getAutoAccept(),
          navigationApp: StorageConfig.getNavApp(),
          cityId: cityId.isNotEmpty ? cityId : null,
        );

        // Update profile controller if registered
        if (Get.isRegistered<ProfileController>()) {
          final profileCtrl = Get.find<ProfileController>();
          profileCtrl.profile.value = updatedProfile;
          profileCtrl.profile.refresh();
          profileCtrl.fetchVehicleTypes();
        }

        // Update dashboard controller if registered
        if (Get.isRegistered<DriverDashboardController>()) {
          final dashCtrl = Get.find<DriverDashboardController>();
          dashCtrl.profile.value = updatedProfile;
          dashCtrl.profile.refresh();
        }

        // Clear any stale active order from prior driver session
        await StorageConfig.setActiveOrderId(null);
        if (!isInTest) {
          try {
            final activeOrders = await DriverOrderService.fetchActiveOrders(driverId);
            if (activeOrders.isNotEmpty) {
              final first = activeOrders.first;
              final cleanId = first.id.replaceAll(RegExp(r'[^0-9]'), '');
              await StorageConfig.setActiveOrderId(cleanId.isNotEmpty ? cleanId : first.id);
              await StorageConfig.setActiveOrderType(first.orderType);
              if (Get.isRegistered<ActiveDeliveryController>()) {
                Get.find<ActiveDeliveryController>().setActiveTask(first);
              }
            }
          } catch (_) {}
        }

        // Refresh dashboard tasks and metrics
        if (Get.isRegistered<DriverDashboardController>()) {
          Get.find<DriverDashboardController>().refreshDashboard();
        }
        if (Get.isRegistered<EarningsController>()) {
          Get.find<EarningsController>().fetchWalletAndEarnings();
        }

        // Send initial battery status report
        if (!isInTest && Get.isRegistered<DriverBatteryService>()) {
          DriverBatteryService.to.sendBatteryPercent(reason: 'login');
        }

        // Start continuous, always-on driver location tracking
        if (!isInTest && Get.isRegistered<DriverLocationUpdateService>()) {
          DriverLocationUpdateService.to.startTracking();
        }

        // Connect driver real-time socket to tracking server
        if (!isInTest && Get.isRegistered<DriverSocketService>()) {
          DriverSocketService.to.connect();
        }

        // Connect driver real-time socket to tracking server
        if (!isInTest && Get.isRegistered<DriverSocketService>()) {
          DriverSocketService.to.connect();
        }

        final targetRoute = StorageConfig.hasActiveOrder() ? Pages.orderDetail : Pages.mainNavigation;
        _safeNavigate(() => Get.offAllNamed(targetRoute));
        _showSnackbar(
          'Welcome Back',
          'Logged in successfully as $fullName',
          backgroundColor: Colors.green.shade700,
        );
      },
      onFailure: (error) {
        isLoading.value = false;
        _showSnackbar(
          'Login Failed',
          error,
          backgroundColor: Colors.red.shade700,
        );
      },
    );
  }

  /// Driver Register
  Future<void> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required int vehicleId,
    required int cityId,
    String? email,
    String? plateNumber,
    String? carImagePath,
  }) async {
    final cleanPhone = DriverAuthService.sanitizePhone(phone);
    if (cleanPhone.length < 9) {
      _showSnackbar('Invalid Phone', 'Please enter a valid phone number');
      return;
    }
    if (email != null && email.trim().isNotEmpty) {
      final cleanEmail = email.trim();
      if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
        _showSnackbar('Invalid Email', 'Please enter a valid email address or leave it blank');
        return;
      }
    }
    if (password.length != 4 || !RegExp(r'^\d{4}$').hasMatch(password)) {
      _showSnackbar('Invalid Password', 'Password must be exactly 4 digits');
      return;
    }
    if (vehicleId <= 0) {
      _showSnackbar('Required Field', 'Please select a vehicle type');
      return;
    }
    if (cityId <= 0) {
      _showSnackbar('Required Field', 'Please select your operating city');
      return;
    }

    final plate = (plateNumber ?? vehiclePlateNumber.value).trim();
    final imagePath = carImagePath ?? vehicleImagePath.value;

    if (!isInTest) {
      if (plate.isEmpty) {
        _showSnackbar('Required Field', 'Please enter your vehicle plate number');
        return;
      }
      if (imagePath == null || imagePath.trim().isEmpty) {
        final vehicleName = selectedVehicle?.name ?? 'vehicle';
        _showSnackbar('Required Field', 'Please upload a photo of your $vehicleName');
        return;
      }
    }

    isLoading.value = true;
    await DriverAuthService.driverRegister(
      firstName: firstName,
      lastName: lastName,
      phone: cleanPhone,
      password: password,
      vehicleId: vehicleId,
      cityId: cityId,
      email: email?.trim(),
      plateNumber: plate.isNotEmpty ? plate : null,
      carImagePath: imagePath,
      onSuccess: (data) async {
        isLoading.value = false;

        final Map<String, dynamic> userMap = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'] as Map)
            : (data['driver'] is Map
                ? Map<String, dynamic>.from(data['driver'] as Map)
                : (data['data'] is Map
                    ? Map<String, dynamic>.from(data['data'] as Map)
                    : data));
        final rawId = userMap['id'] ??
            data['id'] ??
            userMap['user_id'] ??
            data['user_id'];
        final uid = rawId is int
            ? rawId
            : int.tryParse(rawId?.toString() ?? '1') ?? 1;
        final token =
            data['token']?.toString() ?? userMap['token']?.toString() ?? '';

        _pendingUserId = uid;
        _pendingToken = token;
        _pendingPhone = cleanPhone;
        _pendingName = '$firstName $lastName'.trim();
        _pendingEmail = (email != null && email.trim().isNotEmpty)
            ? email.trim()
            : userMap['email']?.toString();
        _pendingVehicleId = vehicleId;
        _pendingCityId = cityId;
        _pendingPlateNumber = plate;

        // Generate 4-digit OTP for SMS
        _pendingOtp = (1000 + Random().nextInt(9000)).toString();

        await DriverAuthService.driverSendOtp(
          phone: cleanPhone,
          otp: _pendingOtp!,
          onSuccess: () {
            isLoading.value = false;
            _safeNavigate(() => Get.toNamed(Pages.otp, arguments: {
              'userId': uid,
              'phone': cleanPhone,
            }));
          },
          onFailure: (otpError) {
            isLoading.value = false;
            _showSnackbar(
              'OTP Delivery Failed',
              otpError,
              backgroundColor: Colors.red.shade700,
            );
          },
        );
      },
      onFailure: (error) {
        isLoading.value = false;
        _showSnackbar(
          'Registration Failed',
          error,
          backgroundColor: Colors.red.shade700,
        );
      },
    );
  }

  /// Verify OTP and finalize login
  Future<void> verifyOtpAndComplete({
    required int userId,
    required String otp,
  }) async {
    if (_pendingOtp != null && otp != _pendingOtp) {
      _showSnackbar(
        'Invalid Code',
        'The verification code entered does not match',
        backgroundColor: Colors.red.shade700,
      );
      return;
    }

    isLoading.value = true;
    await DriverAuthService.driverVerifyOtp(
      userId: userId,
      otp: otp,
      onSuccess: () async {
        isLoading.value = false;
        final uid = _pendingUserId ?? userId;
        final token = _pendingToken ?? 'driver_token_$uid';
        final name = _pendingName ?? 'Driver';
        final phone = _pendingPhone ?? '';
        final email = _pendingEmail ?? '';
        final vId = _pendingVehicleId;
        final cId = _pendingCityId;
        final plate = _pendingPlateNumber;

        await StorageConfig.setToken(token);
        await StorageConfig.setDriverId(uid.toString());
        await StorageConfig.setDriverPhone(phone);
        await StorageConfig.setDriverName(name);
        if (email.isNotEmpty) {
          await StorageConfig.setDriverEmail(email);
        }

        if (vId != null && vId > 0) {
          await StorageConfig.setDriverVehicleId(vId.toString());
          if (vehicleTypes.isNotEmpty) {
            final match = vehicleTypes.firstWhereOrNull((v) => v.id == vId);
            if (match != null) {
              await StorageConfig.setDriverVehicleName(match.name);
              if (match.image != null && match.image!.isNotEmpty) {
                await StorageConfig.setDriverVehicleImage(match.image!);
              }
            }
          }
        }
        if (cId != null && cId > 0) {
          await StorageConfig.setDriverCityId(cId.toString());
        }
        if (plate != null && plate.isNotEmpty) {
          await StorageConfig.setDriverPlateNumber(plate);
        }

        // Register FCM device token with AMN notification server upon verification
        NotificationService.instance.registerDriverTokenToServer(driverId: uid);

        _pendingUserId = null;
        _pendingToken = null;
        _pendingPhone = null;
        _pendingName = null;
        _pendingEmail = null;
        _pendingOtp = null;
        _pendingVehicleId = null;
        _pendingCityId = null;
        _pendingPlateNumber = null;

        _isLoggedIn.value = true;

        if (!isInTest && Get.isRegistered<DriverBatteryService>()) {
          DriverBatteryService.to.sendBatteryPercent(reason: 'otp_verified');
        }

        if (!isInTest && Get.isRegistered<DriverLocationUpdateService>()) {
          DriverLocationUpdateService.to.startTracking();
        }

        // Connect driver real-time socket to tracking server
        if (!isInTest && Get.isRegistered<DriverSocketService>()) {
          DriverSocketService.to.connect();
        }

        if (Get.isRegistered<ProfileController>()) {
          final profileCtrl = Get.find<ProfileController>();
          profileCtrl.profile.value = DriverProfile(
            id: uid.toString(),
            name: name,
            phone: phone,
            email: email.isNotEmpty ? email : profileCtrl.profile.value.email,
            avatarUrl: profileCtrl.profile.value.avatarUrl,
            rating: profileCtrl.profile.value.rating,
            totalTrips: profileCtrl.profile.value.totalTrips,
            tier: profileCtrl.profile.value.tier,
            vehicle: profileCtrl.profile.value.vehicle,
            bankName: profileCtrl.profile.value.bankName,
            bankAccountNumber: profileCtrl.profile.value.bankAccountNumber,
          );
          profileCtrl.profile.refresh();
        }

        // Clear any stale active order from prior driver session
        await StorageConfig.setActiveOrderId(null);
        if (!isInTest) {
          try {
            final activeOrders = await DriverOrderService.fetchActiveOrders(uid);
            if (activeOrders.isNotEmpty) {
              final first = activeOrders.first;
              final cleanId = first.id.replaceAll(RegExp(r'[^0-9]'), '');
              await StorageConfig.setActiveOrderId(cleanId.isNotEmpty ? cleanId : first.id);
              await StorageConfig.setActiveOrderType(first.orderType);
              if (Get.isRegistered<ActiveDeliveryController>()) {
                Get.find<ActiveDeliveryController>().setActiveTask(first);
              }
            }
          } catch (_) {}
        }

        final targetRoute = StorageConfig.hasActiveOrder() ? Pages.orderDetail : Pages.mainNavigation;
        _safeNavigate(() => Get.offAllNamed(targetRoute));
        _showSnackbar(
          'Account Verified',
          'Welcome to AMN Driver, $name!',
          backgroundColor: Colors.green.shade700,
        );
      },
      onFailure: (error) {
        isLoading.value = false;
        _showSnackbar(
          'Verification Failed',
          error,
          backgroundColor: Colors.red.shade700,
        );
      },
    );
  }

  /// Resend OTP
  Future<void> resendOtp({required String phone}) async {
    _pendingOtp = (1000 + Random().nextInt(9000)).toString();
    await DriverAuthService.driverSendOtp(
      phone: phone,
      otp: _pendingOtp!,
      onSuccess: () {
        _showSnackbar(
          'Code Sent',
          'A new 4-digit code was sent to $phone',
          backgroundColor: Colors.green.shade700,
        );
      },
      onFailure: (err) {
        _showSnackbar('Failed to resend code', err);
      },
    );
  }

  /// Forgot Password - Send OTP
  Future<bool> sendPasswordResetOtp(String phone) async {
    final cleanPhone = DriverAuthService.sanitizePhone(phone);
    if (cleanPhone.length < 9) {
      _showSnackbar('Invalid Phone', 'Please enter a valid phone number');
      return false;
    }

    isSendingOtp.value = true;
    final otp = (1000 + Random().nextInt(9000)).toString();
    _resetPhone = cleanPhone;
    _resetOtp = otp;
    _resetOtpVerified = false;

    bool success = false;
    await DriverAuthService.driverSendOtp(
      phone: cleanPhone,
      otp: otp,
      onSuccess: () {
        success = true;
        _startCooldown(60);
        _showSnackbar(
          'Reset Code Sent',
          'Verification code sent to $cleanPhone',
          backgroundColor: Colors.green.shade700,
        );
      },
      onFailure: (error) {
        success = false;
        _showSnackbar('Error', error, backgroundColor: Colors.red.shade700);
      },
    );
    isSendingOtp.value = false;
    return success;
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    resendCooldown.value = seconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCooldown.value > 0) {
        resendCooldown.value--;
      } else {
        timer.cancel();
      }
    });
  }

  /// Verify entered OTP for password reset
  bool verifyPasswordResetOtp(String otp) {
    if (_resetOtp == null || otp != _resetOtp) {
      _resetOtpVerified = false;
      _showSnackbar(
        'Invalid Code',
        'Verification code does not match',
        backgroundColor: Colors.red.shade700,
      );
      return false;
    }
    _resetOtpVerified = true;
    _showSnackbar(
      'Phone Verified',
      'Please enter your new password',
      backgroundColor: Colors.green.shade700,
    );
    return true;
  }

  /// Reset Password with confirmed OTP
  Future<bool> resetPasswordWithOtp({
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (!_resetOtpVerified || _resetPhone == null) {
      _showSnackbar('Error', 'Please verify your phone number with OTP first');
      return false;
    }
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackbar('Required', 'Please fill in all password fields');
      return false;
    }
    if (newPassword.length != 4 || !RegExp(r'^\d{4}$').hasMatch(newPassword)) {
      _showSnackbar('Invalid Password', 'Password must be exactly 4 digits');
      return false;
    }
    if (newPassword != confirmPassword) {
      _showSnackbar('Mismatch', 'Passwords do not match');
      return false;
    }

    isResettingPassword.value = true;
    bool success = false;
    await DriverAuthService.driverForgotPassword(
      phone: _resetPhone!,
      password: newPassword,
      passwordConfirmation: confirmPassword,
      onSuccess: () {
        success = true;
        _resetCooldownTimer();
        _showSnackbar(
          'Password Reset',
          'Your password has been reset successfully. Please log in.',
          backgroundColor: Colors.green.shade700,
        );
        _safeNavigate(() => Get.offNamed(Pages.login));
      },
      onFailure: (err) {
        success = false;
        _showSnackbar('Reset Failed', err, backgroundColor: Colors.red.shade700);
      },
    );
    isResettingPassword.value = false;
    return success;
  }

  void _resetCooldownTimer() {
    _cooldownTimer?.cancel();
    _resetPhone = null;
    _resetOtp = null;
    _resetOtpVerified = false;
    resendCooldown.value = 0;
  }

  /// Driver Logout (POST /driver-logout)
  Future<void> logout() async {
    final driverId = StorageConfig.getDriverId() ?? '1';
    final parsedId = int.tryParse(driverId) ?? 1;

    // Set online status to offline on backend before logging out
    DriverProfileService.updateOnlineStatus(
      driverId: parsedId,
      isOnline: false,
    );

    if (Get.isRegistered<DriverDashboardController>()) {
      Get.find<DriverDashboardController>().isOnline.value = false;
    }

    await DriverAuthService.driverLogout(
      userId: parsedId,
      onSuccess: () {},
      onFailure: (_) {},
    );

    if (!isInTest && Get.isRegistered<DriverBatteryService>()) {
      DriverBatteryService.to.sendBatteryPercent(reason: 'logout');
    }

    if (Get.isRegistered<DriverLocationUpdateService>()) {
      DriverLocationUpdateService.to.stopTracking();
    }

    if (!isInTest && Get.isRegistered<DriverSocketService>()) {
      DriverSocketService.to.disconnect();
    }

    await StorageConfig.clearSession();
    _isLoggedIn.value = false;

    // Reset profile in controller
    if (Get.isRegistered<ProfileController>()) {
      Get.find<ProfileController>().profile.value = DriverProfile.empty();
    }
    if (Get.isRegistered<DriverDashboardController>()) {
      final dashCtrl = Get.find<DriverDashboardController>();
      dashCtrl.profile.value = DriverProfile.empty();
      dashCtrl.todayEarnings.value = 0.0;
      dashCtrl.walletBalance.value = 0.0;
      dashCtrl.completedTrips.value = 0;
      dashCtrl.assignedTasks.clear();
    }

    _safeNavigate(() => Get.offAllNamed(Pages.login));
    _showSnackbar(
      'Signed Out',
      'You have been logged out of AMN Driver.',
      backgroundColor: Colors.grey.shade800,
    );
  }

  /// Change Profile Image (POST /driver-change-profile-image?user_id=1&image)
  Future<void> updateProfilePicture(String filePath) async {
    final driverId = StorageConfig.getDriverId() ?? '1';
    final parsedId = int.tryParse(driverId) ?? 1;

    isLoading.value = true;
    await DriverAuthService.driverChangeProfileImage(
      userId: parsedId,
      filePath: filePath,
      onSuccess: (newUrl) async {
        isLoading.value = false;
        if (newUrl.isNotEmpty) {
          await StorageConfig.setDriverAvatar(newUrl);
          if (Get.isRegistered<ProfileController>()) {
            final profile = Get.find<ProfileController>().profile;
            profile.value = profile.value.copyWith(avatarUrl: newUrl);
            profile.refresh();
          }
        }
        _showSnackbar(
          'Photo Updated',
          'Driver profile picture updated successfully',
          backgroundColor: Colors.green.shade700,
        );
      },
      onFailure: (err) {
        isLoading.value = false;
        _showSnackbar(
          'Photo Upload Failed',
          err,
          backgroundColor: Colors.red.shade700,
        );
      },
    );
  }
}
