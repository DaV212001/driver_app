import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../data/driver_mock_data.dart';
import '../models/city.dart';
import '../models/delivery_price.dart';
import '../models/vehicle_type.dart';
import 'dio_service.dart';

class DriverAuthService {
  /// Helper to robustly extract a `Map<String, dynamic>` from server response
  static Map<String, dynamic>? _parseResponseMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Sanitize phone numbers into international format (supports custom country dial code or defaults to 251 for Ethiopian numbers)
  static String sanitizePhone(String phone, [String? dialCode]) {
    final trimmed = phone.trim();
    if (dialCode != null && dialCode.isNotEmpty) {
      final cleanDial = dialCode.replaceAll(RegExp(r'[^0-9]'), '');
      String cleanPhone = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith(cleanDial)) {
        return cleanPhone;
      }
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }
      return '$cleanDial$cleanPhone';
    }

    if (trimmed.startsWith('+')) {
      return trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    }

    String clean = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('09')) {
      clean = '251${clean.substring(1)}';
    } else if (clean.startsWith('9') && clean.length == 9) {
      clean = '251$clean';
    }
    return clean;
  }

  /// Driver Login (POST /driver-login)
  static Future<void> driverLogin({
    required String phone,
    required String password,
    required FutureOr<void> Function(Map<String, dynamic> data) onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    final cleanPhone = sanitizePhone(phone);
    await DioService.dioPost(
      path: ApiEndpoints.driverLogin,
      data: {
        'phone': cleanPhone,
        'password': password,
      },
      onSuccess: (response) async {
        final resData = _parseResponseMap(response.data);
        if (resData != null) {
          if (resData['success'] == false) {
            await onFailure(resData['message']?.toString() ?? 'Login failed');
            return;
          }
          final userMap = resData['data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(resData['data'] as Map)
              : (resData['data'] is Map
                  ? Map<String, dynamic>.from(resData['data'] as Map)
                  : Map<String, dynamic>.from(resData));
          if (resData['token'] != null && !userMap.containsKey('token')) {
            userMap['token'] = resData['token'];
          }
          await onSuccess(userMap);
        } else {
          await onFailure('Invalid server response');
        }
      },
      onFailure: (error, response) async {
        String msg = 'Driver login failed';
        if (response.data is Map<String, dynamic>) {
          msg = response.data['message']?.toString() ??
              response.data['error']?.toString() ??
              msg;
        } else if (error is DioException && error.response?.data is Map) {
          msg = error.response!.data['message']?.toString() ?? msg;
        }
        await onFailure(msg);
      },
    );
  }

  /// Fetch Vehicle Types (GET /vehicle-type)
  static Future<List<VehicleTypeModel>> fetchVehicleTypes() async {
    List<VehicleTypeModel> list = [];
    await DioService.dioGet(
      path: ApiEndpoints.vehicleType,
      onSuccess: (response) {
        final resData = _parseResponseMap(response.data);
        final rawList = resData != null && resData['data'] is List
            ? resData['data'] as List
            : (response.data is List ? response.data as List : []);
        list = rawList
            .whereType<Map>()
            .map((e) => VehicleTypeModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      onFailure: (error, response) {
        // Handled by caller fallback
      },
    );
    return list;
  }

  /// Fetch Delivery Price by car type and city ID (GET /delivery-price-by-car-and-city-id/{vehicle_id}/{city_id})
  static Future<DeliveryPriceModel?> fetchDeliveryPrice({
    required dynamic vehicleId,
    required dynamic cityId,
  }) async {
    DeliveryPriceModel? price;
    await DioService.dioGet(
      path: ApiEndpoints.deliveryPriceByCarAndCity(vehicleId, cityId),
      onSuccess: (response) {
        final resData = _parseResponseMap(response.data);
        final raw = resData != null && resData['data'] != null
            ? resData['data']
            : response.data;
        if (raw is List && raw.isNotEmpty) {
          final first = raw.first;
          if (first is Map) {
            price = DeliveryPriceModel.fromJson(Map<String, dynamic>.from(first));
          }
        } else if (raw is Map) {
          price = DeliveryPriceModel.fromJson(Map<String, dynamic>.from(raw));
        }
      },
      onFailure: (error, response) {
        // Handled by caller fallback
      },
    );
    return price;
  }

  /// Fetch Cities (GET /city)
  static Future<List<CityModel>> fetchCities() async {
    List<CityModel> list = [];
    await DioService.dioGet(
      path: ApiEndpoints.city,
      onSuccess: (response) {
        final resData = _parseResponseMap(response.data);
        final rawList = resData != null && resData['data'] is List
            ? resData['data'] as List
            : (response.data is List ? response.data as List : []);
        var idx = 1;
        list = rawList
            .whereType<Map>()
            .map((e) => CityModel.fromJson(Map<String, dynamic>.from(e), idx++))
            .toList();
      },
      onFailure: (error, response) {
        // Handled by caller fallback
      },
    );
    if (list.isEmpty) {
      list = List.from(DriverMockData.mockCities);
    }
    return list;
  }

  /// Driver Register (POST /driver-register)
  /// Backend required fields: f_name, l_name, phone, password, vehicle_id, city_id, plate_number, car_image
  /// Optional fields: email
  static Future<void> driverRegister({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required int vehicleId,
    required int cityId,
    String? email,
    String? plateNumber,
    String? carImagePath,
    dynamic carImage,
    required FutureOr<void> Function(Map<String, dynamic> data) onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    final cleanPhone = sanitizePhone(phone);
    final map = <String, dynamic>{
      'f_name': firstName,
      'l_name': lastName,
      'phone': cleanPhone,
      'password': password,
      'vehicle_id': vehicleId,
      'city_id': cityId,
    };
    if (email != null && email.trim().isNotEmpty) {
      map['email'] = email.trim();
    }
    if (plateNumber != null && plateNumber.isNotEmpty) {
      map['plate_number'] = plateNumber;
    }

    dynamic payload;
    if (carImagePath != null && carImagePath.isNotEmpty) {
      final file = File(carImagePath);
      if (await file.exists()) {
        final fileName = carImagePath.split(RegExp(r'[/\\]')).last;
        map['car_image'] = await MultipartFile.fromFile(carImagePath, filename: fileName);
        payload = FormData.fromMap(map);
      } else {
        map['car_image'] = carImagePath;
        payload = map;
      }
    } else if (carImage != null) {
      if (carImage is MultipartFile) {
        map['car_image'] = carImage;
        payload = FormData.fromMap(map);
      } else {
        map['car_image'] = carImage;
        payload = map;
      }
    } else {
      payload = map;
    }

    await DioService.dioPost(
      path: ApiEndpoints.driverRegister,
      data: payload,
      onSuccess: (response) async {
        final resData = _parseResponseMap(response.data);
        if (resData != null) {
          if (resData['success'] == false) {
            await onFailure(resData['message']?.toString() ?? 'Registration failed');
            return;
          }
          final userMap = resData['data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(resData['data'] as Map)
              : (resData['data'] is Map
                  ? Map<String, dynamic>.from(resData['data'] as Map)
                  : Map<String, dynamic>.from(resData));
          if (resData['token'] != null && !userMap.containsKey('token')) {
            userMap['token'] = resData['token'];
          }
          await onSuccess(userMap);
        } else {
          await onFailure('Invalid server response');
        }
      },
      onFailure: (error, response) async {
        String msg = 'Driver registration failed';
        if (response.data is Map<String, dynamic>) {
          final errMap = response.data['errors'];
          if (errMap is Map && errMap.isNotEmpty) {
            final firstErrorList = errMap.values.first;
            if (firstErrorList is List && firstErrorList.isNotEmpty) {
              msg = firstErrorList.first.toString();
            }
          } else {
            msg = response.data['message']?.toString() ?? msg;
          }
        }
        await onFailure(msg);
      },
    );
  }

  /// Driver Send OTP (POST /driver-send-otp)
  static Future<void> driverSendOtp({
    required String phone,
    required String otp,
    required FutureOr<void> Function() onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    final cleanPhone = sanitizePhone(phone);
    await DioService.dioPost(
      path: ApiEndpoints.driverSendOtp,
      data: {
        'phone': cleanPhone,
        'otp': otp,
      },
      onSuccess: (_) async => await onSuccess(),
      onFailure: (error, response) async {
        final resData = _parseResponseMap(response.data);
        String msg = 'Failed to send OTP';
        if (resData != null) {
          if (resData['message'] != null) {
            msg = resData['message'].toString();
          } else if (resData['error'] is Map) {
            final errs = (resData['error'] as Map).values;
            if (errs.isNotEmpty &&
                errs.first is List &&
                (errs.first as List).isNotEmpty) {
              msg = (errs.first as List).first.toString();
            } else {
              msg = resData['error'].toString();
            }
          } else if (resData['error'] != null) {
            msg = resData['error'].toString();
          }
        } else if (error is DioException && error.message != null) {
          msg = error.message!;
        }
        await onFailure(msg);
      },
    );
  }

  /// Driver Verify OTP (POST /driver-verify-otp)
  static Future<void> driverVerifyOtp({
    required dynamic userId,
    required String otp,
    required FutureOr<void> Function() onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    await DioService.dioPost(
      path: ApiEndpoints.driverVerifyOtp,
      data: {
        'user_id': userId.toString(),
        'otp': otp,
      },
      onSuccess: (_) async => await onSuccess(),
      onFailure: (error, response) async {
        final msg = response.data is Map
            ? response.data['message']?.toString() ?? 'Invalid verification code'
            : 'Invalid verification code';
        await onFailure(msg);
      },
    );
  }

  /// Forget Driver Password (POST /driver-forget-password)
  static Future<void> driverForgotPassword({
    required String phone,
    required String password,
    required String passwordConfirmation,
    required FutureOr<void> Function() onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    final cleanPhone = sanitizePhone(phone);
    await DioService.dioPost(
      path: ApiEndpoints.driverForgetPassword,
      data: {
        'phone': cleanPhone,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      onSuccess: (_) async => await onSuccess(),
      onFailure: (error, response) async {
        final msg = response.data is Map
            ? response.data['message']?.toString() ?? 'Failed to reset driver password'
            : 'Failed to reset driver password';
        await onFailure(msg);
      },
    );
  }

  /// Change Driver Password (POST /driver-change-password)
  static Future<void> driverChangePassword({
    required dynamic userId,
    required String password,
    required String passwordConfirmation,
    required FutureOr<void> Function() onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    await DioService.dioPost(
      path: ApiEndpoints.driverChangePassword,
      data: {
        'user_id': userId,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      onSuccess: (_) async => await onSuccess(),
      onFailure: (error, response) async {
        final msg = response.data is Map
            ? response.data['message']?.toString() ?? 'Failed to change password'
            : 'Failed to change password';
        await onFailure(msg);
      },
    );
  }

  /// Driver Logout (POST /driver-logout)
  static Future<void> driverLogout({
    required dynamic userId,
    required FutureOr<void> Function() onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    await DioService.dioPost(
      path: ApiEndpoints.driverLogout,
      data: {'user_id': userId},
      onSuccess: (_) async => await onSuccess(),
      onFailure: (error, response) async => await onSuccess(), // Succeeded locally
    );
  }

  /// Driver Change Profile Picture (POST /driver-change-profile-image?user_id=1&image)
  /// Automatically falls back to /customer-change-profile-image if user ID exists in users table.
  static Future<void> driverChangeProfileImage({
    required dynamic userId,
    required String filePath,
    required FutureOr<void> Function(String newImageUrl) onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    final fileName = filePath.split(RegExp(r'[/\\]')).last;

    Future<FormData> makeFormData() async => FormData.fromMap({
      'user_id': userId.toString(),
      'image': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    Future<void> parseResponse(dynamic response) async {
      String newUrl = '';
      if (response.data is Map) {
        final map = response.data as Map;
        final data = map['data'];
        if (data is Map) {
          final picture = data['profile_picture']?.toString();
          final profileImg = data['profile_image']?.toString();
          final image = data['image']?.toString();
          final url = data['url']?.toString();
          final avatar = data['avatar']?.toString();

          if (picture != null && picture.trim().isNotEmpty) {
            newUrl = picture.trim();
          } else if (profileImg != null && profileImg.trim().isNotEmpty) {
            newUrl = profileImg.trim();
          } else if (image != null && image.trim().isNotEmpty) {
            newUrl = image.trim();
          } else if (url != null && url.trim().isNotEmpty) {
            newUrl = url.trim();
          } else if (avatar != null && avatar.trim().isNotEmpty) {
            newUrl = avatar.trim();
          }
        } else if (data is String && data.trim().isNotEmpty) {
          newUrl = data.trim();
        } else {
          final picture = map['profile_picture']?.toString();
          final profileImg = map['profile_image']?.toString();
          final image = map['image']?.toString();
          final url = map['url']?.toString();

          if (picture != null && picture.trim().isNotEmpty) {
            newUrl = picture.trim();
          } else if (profileImg != null && profileImg.trim().isNotEmpty) {
            newUrl = profileImg.trim();
          } else if (image != null && image.trim().isNotEmpty) {
            newUrl = image.trim();
          } else if (url != null && url.trim().isNotEmpty) {
            newUrl = url.trim();
          }
        }
      } else if (response.data is String) {
        newUrl = response.data.toString().trim();
      }
      await onSuccess(newUrl);
    }

    // Try primary driver profile image endpoint
    final primaryFormData = await makeFormData();
    bool primarySuccess = false;

    await DioService.dioUpload(
      path: '${ApiEndpoints.driverChangeProfileImage}?user_id=$userId',
      formData: primaryFormData,
      onSuccess: (response) async {
        primarySuccess = true;
        await parseResponse(response);
      },
      onFailure: (error, response) async {
        // Will attempt fallback below
      },
    );

    if (primarySuccess) return;

    // Fallback: Try customer profile image endpoint (for accounts mapped under users table)
    final fallbackFormData = await makeFormData();
    await DioService.dioUpload(
      path: '${ApiEndpoints.customerChangeProfileImage}?user_id=$userId',
      formData: fallbackFormData,
      onSuccess: parseResponse,
      onFailure: (error, response) async {
        final msg = response.data is Map
            ? response.data['message']?.toString() ?? 'Failed to upload photo'
            : 'Failed to upload photo';
        await onFailure(msg);
      },
    );
  }
}
