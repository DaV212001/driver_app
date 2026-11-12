import 'dart:async';
import 'dart:convert';
import '../config/storage_config.dart';
import '../constants/api_endpoints.dart';
import 'dio_service.dart';
import 'driver_auth_service.dart';

class DriverProfileService {
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

  /// Fetch driver profile (GET /driver-profile/{id})
  static Future<Map<String, dynamic>?> fetchProfile(dynamic driverId) async {
    final id = driverId ?? StorageConfig.getDriverId();
    if (id == null || id.toString().isEmpty) return null;

    Map<String, dynamic>? result;
    await DioService.dioGet(
      path: ApiEndpoints.driverProfile(id),
      onSuccess: (response) {
        final resData = _parseResponseMap(response.data);
        if (resData != null) {
          result = resData.containsKey('data') && resData['data'] is Map
              ? resData
              : {'data': resData};
        }
      },
      onFailure: (error, response) {},
    );
    return result;
  }

  /// Update driver profile (PUT /driver-profile/{id})
  static Future<void> updateProfile({
    required dynamic driverId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required FutureOr<void> Function(Map<String, dynamic> data) onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    final cleanPhone = DriverAuthService.sanitizePhone(phone);
    final finalPhone = cleanPhone.isNotEmpty ? cleanPhone : phone.trim();

    await DioService.dioPut(
      path: ApiEndpoints.driverProfile(driverId),
      data: {
        'f_name': firstName.trim(),
        'l_name': lastName.trim(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim(),
        'phone': finalPhone,
      },
      onSuccess: (response) async {
        final resData = _parseResponseMap(response.data);
        if (resData != null) {
          if (resData['success'] == false) {
            await onFailure(resData['message']?.toString() ?? 'Failed to update profile');
            return;
          }
          final userMap = resData['data'] is Map
              ? Map<String, dynamic>.from(resData['data'] as Map)
              : (resData['user'] is Map
                  ? Map<String, dynamic>.from(resData['user'] as Map)
                  : Map<String, dynamic>.from(resData));
          await onSuccess(userMap);
        } else {
          await onSuccess({});
        }
      },
      onFailure: (error, response) async {
        String msg = 'Failed to update profile';
        if (response.data is Map<String, dynamic>) {
          msg = response.data['message']?.toString() ?? msg;
        }
        await onFailure(msg);
      },
    );
  }

  /// Robust helper to parse number/money amounts from dynamic API response values
  static double _parseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    if (raw is Map) {
      final inner = raw['amount'] ?? raw['balance'] ?? raw['data'] ?? raw['wallet'] ?? raw['earning'];
      return _parseAmount(inner);
    }
    return 0.0;
  }

  /// Fetch driver wallet amount (GET /driver_my_wallet_amount/{id})
  static Future<double?> fetchWalletAmount(dynamic driverId) async {
    final id = driverId ?? StorageConfig.getDriverId();
    if (id == null || id.toString().isEmpty) return null;

    double? balance;
    await DioService.dioGet(
      path: ApiEndpoints.driverWalletAmount(id),
      onSuccess: (response) {
        final data = _parseResponseMap(response.data);
        if (data != null) {
          final raw = data.containsKey('data') ? data['data'] : (data['amount'] ?? data['wallet']);
          balance = _parseAmount(raw);
        } else if (response.data is num) {
          balance = (response.data as num).toDouble();
        } else if (response.data is String) {
          balance = _parseAmount(response.data);
        }
      },
      onFailure: (error, response) {},
    );
    return balance;
  }

  /// Top-up driver wallet via Chapa (POST /driver-wallet-payment)
  static Future<void> topupWallet({
    required dynamic driverId,
    required double amount,
    required String date,
    required FutureOr<void> Function(String? checkoutUrl, String message) onSuccess,
    required FutureOr<void> Function(String error) onFailure,
  }) async {
    await DioService.dioPost(
      path: ApiEndpoints.driverWalletPayment,
      data: {
        'user_id': driverId,
        'amount': amount,
        'date': date,
      },
      onSuccess: (response) async {
        String? checkoutUrl;
        String message = 'Payment initialized';

        final resData = _parseResponseMap(response.data);
        if (resData != null) {
          message = resData['message']?.toString() ?? message;

          if (resData['data'] is Map) {
            final inner = Map<String, dynamic>.from(resData['data'] as Map);
            checkoutUrl = inner['checkout_url']?.toString() ??
                inner['payment_url']?.toString() ??
                inner['url']?.toString();
          }

          checkoutUrl ??= resData['checkout_url']?.toString() ??
              resData['payment_url']?.toString() ??
              resData['url']?.toString();
        }

        await onSuccess(checkoutUrl, message);
      },
      onFailure: (error, response) async {
        String msg = 'Wallet top-up failed';
        final resData = _parseResponseMap(response.data);
        if (resData != null) {
          msg = resData['message']?.toString() ?? msg;
        }
        await onFailure(msg);
      },
    );
  }

  /// Fetch driver today earning (GET /today_earning/$driverId)
  static Future<double?> fetchTodayEarning(dynamic driverId) async {
    double? earning;
    await DioService.dioGet(
      path: ApiEndpoints.todayEarning(driverId),
      onSuccess: (response) {
        final data = _parseResponseMap(response.data);
        if (data != null) {
          final raw = data.containsKey('data') ? data['data'] : (data['amount'] ?? data['earning']);
          earning = _parseAmount(raw);
        } else if (response.data is num) {
          earning = (response.data as num).toDouble();
        } else if (response.data is String) {
          earning = _parseAmount(response.data);
        }
      },
      onFailure: (error, response) {},
    );
    return earning;
  }

  /// Fetch terms and conditions (GET /term_and_condition)
  static Future<String?> fetchTermsAndConditions() async {
    String? terms;
    await DioService.dioGet(
      path: ApiEndpoints.termsAndConditions,
      onSuccess: (response) {
        final map = _parseResponseMap(response.data);
        if (map != null) {
          terms = map['data']?.toString() ?? map['message']?.toString();
        } else if (response.data is String) {
          terms = response.data as String;
        }
      },
      onFailure: (error, response) {},
    );
    return terms;
  }

  /// Update driver online status (POST /driver/$driverId/update-online)
  /// Request body: {"online": 1} (online) or {"online": 0} (offline)
  static Future<bool> updateOnlineStatus({
    required dynamic driverId,
    required bool isOnline,
    Function(Map<String, dynamic> data)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    bool success = false;
    await DioService.dioPost(
      path: ApiEndpoints.updateOnline(driverId),
      data: {
        'online': isOnline ? 1 : 0,
      },
      onSuccess: (response) {
        success = true;
        final resData = _parseResponseMap(response.data);
        if (resData != null) {
          onSuccess?.call(resData);
        } else {
          onSuccess?.call({'success': true});
        }
      },
      onFailure: (error, response) {
        String msg = 'Failed to update online status';
        if (response.data is Map<String, dynamic>) {
          msg = response.data['message']?.toString() ?? msg;
        }
        onFailure?.call(msg);
      },
    );
    return success;
  }
}
