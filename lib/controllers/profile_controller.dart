import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../config/storage_config.dart';
import '../models/driver_profile.dart';
import '../models/vehicle_type.dart';
import '../services/driver_auth_service.dart';
import '../services/driver_profile_service.dart';
import 'driver_auth_controller.dart';
import 'driver_dashboard_controller.dart';

class ProfileController extends GetxController {
  final Rx<DriverProfile> profile = DriverProfile.fromStorage().obs;
  final RxList<VehicleTypeModel> vehicleTypes = <VehicleTypeModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isUpdating = false.obs;
  final RxBool isUploadingPhoto = false.obs;

  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    _loadStoredProfile();
    fetchVehicleTypes();
    fetchProfileFromApi();
  }

  void _loadStoredProfile() {
    final storedName = StorageConfig.getDriverName();
    final storedPhone = StorageConfig.getDriverPhone();
    final storedAvatar = StorageConfig.getDriverAvatar();
    final storedId = StorageConfig.getDriverId();
    final storedEmail = StorageConfig.getDriverEmail();
    final storedVehicleId = StorageConfig.getDriverVehicleId();
    final storedPlate = StorageConfig.getDriverPlateNumber();
    final storedCityId = StorageConfig.getDriverCityId();
    final storedVehicleName = StorageConfig.getDriverVehicleName();
    final storedVehicleImage = StorageConfig.getDriverVehicleImage();

    final vId = storedVehicleId != null ? int.tryParse(storedVehicleId) : null;
    final vName = (storedVehicleName != null && storedVehicleName.isNotEmpty)
        ? storedVehicleName
        : (vId != null ? 'Vehicle #$vId' : '');

    profile.value = profile.value.copyWith(
      id: storedId ?? profile.value.id,
      name: storedName ?? profile.value.name,
      phone: storedPhone ?? profile.value.phone,
      email: storedEmail ?? profile.value.email,
      avatarUrl: storedAvatar ?? profile.value.avatarUrl,
      cityId: storedCityId ?? profile.value.cityId,
      vehicle: profile.value.vehicle.copyWith(
        vehicleId: vId ?? profile.value.vehicle.vehicleId,
        type: vName.isNotEmpty ? vName : profile.value.vehicle.type,
        model: vName.isNotEmpty ? vName : profile.value.vehicle.model,
        plateNumber: storedPlate ?? profile.value.vehicle.plateNumber,
        imageUrl: storedVehicleImage ?? profile.value.vehicle.imageUrl,
        isVerified: (storedPlate != null && storedPlate.isNotEmpty) || vId != null,
      ),
      autoAcceptOrders: StorageConfig.getAutoAccept(),
      navigationApp: StorageConfig.getNavApp(),
    );
    profile.refresh();
  }

  /// Fetch vehicle types from API and resolve vehicle name/image for the driver
  Future<void> fetchVehicleTypes() async {
    try {
      final list = await DriverAuthService.fetchVehicleTypes();
      if (list.isNotEmpty) {
        vehicleTypes.assignAll(list);
        final currentVId = profile.value.vehicle.vehicleId ??
            (StorageConfig.getDriverVehicleId() != null
                ? int.tryParse(StorageConfig.getDriverVehicleId()!)
                : null);

        if (currentVId != null) {
          final matched = list.firstWhereOrNull((v) => v.id == currentVId);
          if (matched != null) {
            await StorageConfig.setDriverVehicleName(matched.name);
            if (matched.image != null && matched.image!.isNotEmpty) {
              await StorageConfig.setDriverVehicleImage(matched.image!);
            }
            profile.value = profile.value.copyWith(
              vehicle: profile.value.vehicle.copyWith(
                vehicleId: currentVId,
                type: matched.name,
                model: matched.name,
                imageUrl: matched.image,
                isVerified: true,
              ),
            );
            profile.refresh();
          }
        }
      }
    } catch (_) {
      // Graceful fallback to cached vehicle data
    }
  }

  /// Robust helper to parse number/money amounts from dynamic API response values
  double _parseAmount(dynamic raw, double fallback) {
    if (raw == null) return fallback;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? fallback;
    }
    return fallback;
  }

  Future<void>? _activeFetch;

  /// Fetch driver profile from live backend API (GET /driver-profile/{id})
  Future<void> fetchProfileFromApi() async {
    if (_activeFetch != null) return _activeFetch!;
    _activeFetch = _performFetchProfile();
    try {
      await _activeFetch;
    } finally {
      _activeFetch = null;
    }
  }

  Future<void> _performFetchProfile() async {
    final driverId = StorageConfig.getDriverId() ?? '1';
    if (driverId.isEmpty) return;

    isLoading.value = true;
    try {
      final results = await Future.wait([
        DriverProfileService.fetchProfile(driverId),
        DriverProfileService.fetchWalletAmount(driverId),
      ]);
      final res = results[0] as Map<String, dynamic>?;
      final liveWallet = results[1] as double?;

      if (res != null) {
        final userMap = res['data'] is Map
            ? Map<String, dynamic>.from(res['data'] as Map)
            : (res['user'] is Map
                ? Map<String, dynamic>.from(res['user'] as Map)
                : Map<String, dynamic>.from(res));

        final firstName = userMap['f_name']?.toString() ??
            userMap['first_name']?.toString() ??
            '';
        final lastName = userMap['l_name']?.toString() ??
            userMap['last_name']?.toString() ??
            '';
        String fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
            ? '$firstName $lastName'.trim()
            : (userMap['name']?.toString() ?? '');
        if (fullName.isEmpty) {
          fullName = profile.value.name.isNotEmpty
              ? profile.value.name
              : (StorageConfig.getDriverName() ?? 'Driver');
        }

        final phone = userMap['phone']?.toString() ?? profile.value.phone;
        final email = userMap['email']?.toString() ?? profile.value.email;

        // Extract real avatar image URL (profile_picture contains the full storage URL)
        String avatar = '';
        final rawPic = userMap['profile_picture']?.toString().trim();
        final rawImg = userMap['profile_image']?.toString().trim();
        final rawAvt = userMap['avatar']?.toString().trim();
        final rawImage = userMap['image']?.toString().trim();

        if (rawPic != null && rawPic.isNotEmpty) {
          avatar = rawPic;
        } else if (rawImg != null && rawImg.isNotEmpty) {
          avatar = rawImg;
        } else if (rawAvt != null && rawAvt.isNotEmpty) {
          avatar = rawAvt;
        } else if (rawImage != null && rawImage.isNotEmpty) {
          avatar = rawImage;
        } else {
          avatar = profile.value.avatarUrl;
        }

        final walletVal = liveWallet ??
            _parseAmount(
              userMap['wallet_amount'] ?? userMap['amount'] ?? userMap['wallet'],
              profile.value.walletAmount,
            );

        final ratingVal = _parseAmount(
          userMap['rating'],
          profile.value.rating,
        );

        final tripsVal = int.tryParse(
          userMap['total_orders']?.toString() ??
              userMap['total_trips']?.toString() ??
              userMap['trips']?.toString() ??
              '',
        ) ?? profile.value.totalTrips;

        // Persist fresh server values to local storage
        if (fullName.isNotEmpty && fullName != 'Driver') await StorageConfig.setDriverName(fullName);
        if (phone.isNotEmpty) await StorageConfig.setDriverPhone(phone);
        if (email.isNotEmpty) await StorageConfig.setDriverEmail(email);
        if (avatar.isNotEmpty) await StorageConfig.setDriverAvatar(avatar);

        final serverVehicleId = userMap['vehicle_id']?.toString();
        final serverPlate = userMap['plate_number']?.toString();
        final serverCityId = userMap['city_id']?.toString();
        final serverCarImage = userMap['car_image']?.toString().trim();

        if (serverVehicleId != null && serverVehicleId.isNotEmpty) {
          await StorageConfig.setDriverVehicleId(serverVehicleId);
        }
        if (serverPlate != null && serverPlate.isNotEmpty) {
          await StorageConfig.setDriverPlateNumber(serverPlate);
        }
        if (serverCityId != null && serverCityId.isNotEmpty) {
          await StorageConfig.setDriverCityId(serverCityId);
        }
        if (serverCarImage != null && serverCarImage.isNotEmpty) {
          await StorageConfig.setDriverVehicleImage(serverCarImage);
        }

        final activeVId = serverVehicleId != null && serverVehicleId.isNotEmpty
            ? int.tryParse(serverVehicleId)
            : (profile.value.vehicle.vehicleId ??
                (StorageConfig.getDriverVehicleId() != null
                    ? int.tryParse(StorageConfig.getDriverVehicleId()!)
                    : null));

        final activePlate = (serverPlate != null && serverPlate.isNotEmpty)
            ? serverPlate
            : (profile.value.vehicle.plateNumber.isNotEmpty
                ? profile.value.vehicle.plateNumber
                : (StorageConfig.getDriverPlateNumber() ?? ''));

        final activeVehicleName = profile.value.vehicle.type.isNotEmpty
            ? profile.value.vehicle.type
            : (StorageConfig.getDriverVehicleName() ?? '');
        final activeVehicleImage = (serverCarImage != null && serverCarImage.isNotEmpty)
            ? serverCarImage
            : (profile.value.vehicle.imageUrl ?? StorageConfig.getDriverVehicleImage());

        profile.value = profile.value.copyWith(
          id: driverId,
          name: fullName,
          phone: phone.isNotEmpty ? phone : (StorageConfig.getDriverPhone() ?? profile.value.phone),
          email: email.isNotEmpty ? email : (StorageConfig.getDriverEmail() ?? profile.value.email),
          avatarUrl: avatar.isNotEmpty ? avatar : (StorageConfig.getDriverAvatar() ?? profile.value.avatarUrl),
          walletAmount: walletVal,
          rating: ratingVal,
          totalTrips: tripsVal,
          cityId: serverCityId ?? StorageConfig.getDriverCityId() ?? profile.value.cityId,
          vehicle: profile.value.vehicle.copyWith(
            vehicleId: activeVId,
            type: activeVehicleName,
            model: activeVehicleName,
            plateNumber: activePlate,
            imageUrl: activeVehicleImage,
            isVerified: activePlate.isNotEmpty || activeVId != null,
          ),
        );
        profile.refresh();
        if (Get.isRegistered<DriverDashboardController>()) {
          Get.find<DriverDashboardController>().profile.value = profile.value;
          Get.find<DriverDashboardController>().profile.refresh();
          Get.find<DriverDashboardController>().driverRating.value = profile.value.rating;
        }

        // Trigger vehicle types fetch to resolve vehicle name if still empty
        if (activeVId != null && (activeVehicleName.isEmpty || activeVehicleName.startsWith('Vehicle #'))) {
          fetchVehicleTypes();
        }
      }
    } catch (_) {
      // Keep existing cached profile on error
    } finally {
      isLoading.value = false;
    }
  }

  /// Update driver profile details (PUT /driver-profile/{id})
  Future<bool> updateProfileInfo({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    final driverId = StorageConfig.getDriverId() ?? '1';
    isUpdating.value = true;
    bool success = false;

    await DriverProfileService.updateProfile(
      driverId: driverId,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      onSuccess: (data) async {
        success = true;
        final updatedFirst = data['f_name']?.toString() ?? firstName;
        final updatedLast = data['l_name']?.toString() ?? lastName;
        final updatedName = '$updatedFirst $updatedLast'.trim();
        final updatedEmail = data['email']?.toString() ?? email;
        final updatedPhone = data['phone']?.toString() ?? phone;

        if (updatedName.isNotEmpty) {
          await StorageConfig.setDriverName(updatedName);
        }
        if (updatedEmail.isNotEmpty) {
          await StorageConfig.setDriverEmail(updatedEmail);
        }
        if (updatedPhone.isNotEmpty) {
          await StorageConfig.setDriverPhone(updatedPhone);
        }

        profile.value = profile.value.copyWith(
          name: updatedName.isNotEmpty ? updatedName : profile.value.name,
          email: updatedEmail.isNotEmpty ? updatedEmail : profile.value.email,
          phone: updatedPhone.isNotEmpty ? updatedPhone : profile.value.phone,
        );
        profile.refresh();
        if (Get.isRegistered<DriverDashboardController>()) {
          Get.find<DriverDashboardController>().profile.value = profile.value;
          Get.find<DriverDashboardController>().driverRating.value = profile.value.rating;
        }

        if (Get.context != null && Get.overlayContext != null && !Get.testMode) {
          Get.snackbar(
            'Profile Updated',
            'Your driver details have been updated successfully.',
            backgroundColor: Colors.green.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      },
      onFailure: (error) {
        success = false;
        if (Get.context != null && Get.overlayContext != null && !Get.testMode) {
          Get.snackbar(
            'Update Failed',
            error,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      },
    );

    isUpdating.value = false;
    return success;
  }

  /// Pick image from camera or gallery and upload
  Future<void> pickAndUploadProfileImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        await updateProfilePicture(pickedFile.path);
      }
    } catch (e) {
      if (Get.context != null && Get.overlayContext != null && !Get.testMode) {
        Get.snackbar(
          'Image Selection Error',
          'Could not pick image: $e',
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
      }
    }
  }

  /// Change profile picture via tested multipart endpoints
  Future<void> updateProfilePicture(String filePath) async {
    final driverId = StorageConfig.getDriverId() ?? '1';
    isUploadingPhoto.value = true;

    await DriverAuthService.driverChangeProfileImage(
      userId: driverId,
      filePath: filePath,
      onSuccess: (newUrl) async {
        isUploadingPhoto.value = false;
        if (newUrl.isNotEmpty) {
          await StorageConfig.setDriverAvatar(newUrl);
          profile.value = profile.value.copyWith(avatarUrl: newUrl);
          profile.refresh();
        if (Get.isRegistered<DriverDashboardController>()) {
          Get.find<DriverDashboardController>().profile.value = profile.value;
          Get.find<DriverDashboardController>().driverRating.value = profile.value.rating;
        }
        }
        if (Get.context != null && Get.overlayContext != null && !Get.testMode) {
          Get.snackbar(
            'Photo Updated',
            'Driver profile image updated successfully.',
            backgroundColor: Colors.green.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      },
      onFailure: (err) {
        isUploadingPhoto.value = false;
        if (Get.context != null && Get.overlayContext != null && !Get.testMode) {
          Get.snackbar(
            'Upload Failed',
            err,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      },
    );
  }

  void toggleAutoAccept(bool val) {
    profile.value.autoAcceptOrders = val;
    StorageConfig.setAutoAccept(val);
    profile.refresh();
  }

  void setNavigationApp(String app) {
    profile.value.navigationApp = app;
    StorageConfig.setNavApp(app);
    profile.refresh();
  }

  void logOut() {
    Get.defaultDialog(
      title: 'Log Out',
      middleText: 'Are you sure you want to log out of AMN Driver?',
      textConfirm: 'Log Out',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      textCancel: 'Cancel',
      onConfirm: () async {
        Get.back();
        if (Get.isRegistered<DriverAuthController>()) {
          await Get.find<DriverAuthController>().logout();
        } else {
          await StorageConfig.clearSession();
          Get.snackbar(
            'Logged Out',
            'You have successfully signed out.',
            backgroundColor: Colors.white,
          );
        }
      },
    );
  }
}
