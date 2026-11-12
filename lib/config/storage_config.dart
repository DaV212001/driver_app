import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageConfig {
  static SharedPreferences? _prefs;

  static const String _keyToken = 'driver_auth_token';
  static const String _keyDriverId = 'driver_id';
  static const String _keyDriverName = 'driver_name';
  static const String _keyDriverPhone = 'driver_phone';
  static const String _keyDriverEmail = 'driver_email';
  static const String _keyDriverAvatar = 'driver_avatar';
  static const String _keyAutoAccept = 'driver_auto_accept';
  static const String _keyNavApp = 'driver_nav_app';
  static const String _keyDarkMode = 'driver_dark_mode';
  static const String _keyIsOnline = 'driver_is_online';
  static const String _keyActiveOrderId = 'driver_active_order_id';
  static const String _keyActiveOrderType = 'driver_active_order_type';
  static const String _keyActiveTaskJson = 'driver_active_task_json';
  static const String _keyDeviceId = 'driver_device_id';
  static const String _keyLocationDisclosureAgreed = 'location_prominent_disclosure_agreed';
  static const String _keyDriverVehicleId = 'driver_vehicle_id';
  static const String _keyDriverPlateNumber = 'driver_plate_number';
  static const String _keyDriverCityId = 'driver_city_id';
  static const String _keyDriverVehicleName = 'driver_vehicle_name';
  static const String _keyDriverVehicleImage = 'driver_vehicle_image';
  static const String _keyDriverPickupKmPrice = 'driver_pickup_km_price';
  static const String _keyDriverPickupStartPrice = 'driver_pickup_start_price';

  static String? _cachedDeviceId;
  static String? _cachedActiveOrderId;
  static String? _cachedActiveOrderType;
  static bool? _cachedIsOnline;
  static bool _cachedActiveOrderInitialized = false;

  static Future<void> init([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    _cachedActiveOrderId = _prefs?.getString(_keyActiveOrderId);
    _cachedActiveOrderType = _prefs?.getString(_keyActiveOrderType);
    _cachedIsOnline = _prefs?.getBool(_keyIsOnline);
    _cachedActiveOrderInitialized = true;
    await initDeviceId();
  }

  static bool isLoggedIn() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }

  static String? getToken() => _prefs?.getString(_keyToken);
  static Future<bool> setToken(String token) async =>
      await _prefs?.setString(_keyToken, token) ?? false;

  static String? getDriverId() => _prefs?.getString(_keyDriverId);
  static Future<bool> setDriverId(String id) async =>
      await _prefs?.setString(_keyDriverId, id) ?? false;

  static String? getDriverName() => _prefs?.getString(_keyDriverName);
  static Future<bool> setDriverName(String name) async =>
      await _prefs?.setString(_keyDriverName, name) ?? false;

  static String? getDriverPhone() => _prefs?.getString(_keyDriverPhone);
  static Future<bool> setDriverPhone(String phone) async =>
      await _prefs?.setString(_keyDriverPhone, phone) ?? false;

  static String? getDriverEmail() => _prefs?.getString(_keyDriverEmail);
  static Future<bool> setDriverEmail(String email) async =>
      await _prefs?.setString(_keyDriverEmail, email) ?? false;

  static String? getDriverAvatar() => _prefs?.getString(_keyDriverAvatar);
  static Future<bool> setDriverAvatar(String avatarUrl) async =>
      await _prefs?.setString(_keyDriverAvatar, avatarUrl) ?? false;

  static String? getDriverVehicleId() => _prefs?.getString(_keyDriverVehicleId);
  static Future<bool> setDriverVehicleId(String id) async =>
      await _prefs?.setString(_keyDriverVehicleId, id) ?? false;

  static String? getDriverPlateNumber() => _prefs?.getString(_keyDriverPlateNumber);
  static Future<bool> setDriverPlateNumber(String plate) async =>
      await _prefs?.setString(_keyDriverPlateNumber, plate) ?? false;

  static String? getDriverCityId() => _prefs?.getString(_keyDriverCityId);
  static Future<bool> setDriverCityId(String cityId) async =>
      await _prefs?.setString(_keyDriverCityId, cityId) ?? false;

  static String? getDriverVehicleName() => _prefs?.getString(_keyDriverVehicleName);
  static Future<bool> setDriverVehicleName(String name) async =>
      await _prefs?.setString(_keyDriverVehicleName, name) ?? false;

  static String? getDriverVehicleImage() => _prefs?.getString(_keyDriverVehicleImage);
  static Future<bool> setDriverVehicleImage(String url) async =>
      await _prefs?.setString(_keyDriverVehicleImage, url) ?? false;

  static double? getPickupKmPrice() => _prefs?.getDouble(_keyDriverPickupKmPrice);
  static Future<bool> setPickupKmPrice(double price) async =>
      await _prefs?.setDouble(_keyDriverPickupKmPrice, price) ?? false;

  static double? getPickupStartPrice() => _prefs?.getDouble(_keyDriverPickupStartPrice);
  static Future<bool> setPickupStartPrice(double price) async =>
      await _prefs?.setDouble(_keyDriverPickupStartPrice, price) ?? false;

  static bool getAutoAccept() => _prefs?.getBool(_keyAutoAccept) ?? false;
  static Future<bool> setAutoAccept(bool val) async =>
      await _prefs?.setBool(_keyAutoAccept, val) ?? false;

  static String getNavApp() => _prefs?.getString(_keyNavApp) ?? 'Google Maps';
  static Future<bool> setNavApp(String app) async =>
      await _prefs?.setString(_keyNavApp, app) ?? false;

  // Dark mode (Default is false / Light Mode)
  static bool isDarkMode() => _prefs?.getBool(_keyDarkMode) ?? false;
  static Future<bool> setDarkMode(bool val) async =>
      await _prefs?.setBool(_keyDarkMode, val) ?? false;

  // Driver online status
  static bool getIsOnline() => _cachedIsOnline ?? _prefs?.getBool(_keyIsOnline) ?? false;
  static Future<bool> setIsOnline(bool val) async {
    _cachedIsOnline = val;
    return await _prefs?.setBool(_keyIsOnline, val) ?? false;
  }

  // Active delivery order in progress
  static String? getActiveOrderId() => _cachedActiveOrderInitialized
      ? _cachedActiveOrderId
      : (_cachedActiveOrderId ?? _prefs?.getString(_keyActiveOrderId));

  static Future<bool> setActiveOrderId(String? orderId) async {
    _cachedActiveOrderId = (orderId != null && orderId.isNotEmpty) ? orderId : null;
    _cachedActiveOrderInitialized = true;
    if (orderId == null || orderId.isEmpty) {
      _cachedActiveOrderType = null;
      _prefs?.remove(_keyActiveOrderId);
      _prefs?.remove(_keyActiveOrderType);
      return await _prefs?.remove(_keyActiveTaskJson) ?? false;
    }
    return await _prefs?.setString(_keyActiveOrderId, orderId) ?? false;
  }

  static String? getActiveOrderType() => _cachedActiveOrderInitialized
      ? _cachedActiveOrderType
      : (_cachedActiveOrderType ?? _prefs?.getString(_keyActiveOrderType));

  static Future<bool> setActiveOrderType(String? orderType) async {
    _cachedActiveOrderType = (orderType != null && orderType.isNotEmpty) ? orderType : null;
    _cachedActiveOrderInitialized = true;
    if (orderType == null || orderType.isEmpty) {
      return await _prefs?.remove(_keyActiveOrderType) ?? false;
    }
    return await _prefs?.setString(_keyActiveOrderType, orderType) ?? false;
  }

  static String? getActiveTaskJson() => _prefs?.getString(_keyActiveTaskJson);
  static Future<bool> setActiveTaskJson(String? jsonStr) async {
    if (jsonStr == null || jsonStr.isEmpty) {
      return await _prefs?.remove(_keyActiveTaskJson) ?? false;
    }
    return await _prefs?.setString(_keyActiveTaskJson, jsonStr) ?? false;
  }

  static bool hasActiveOrder() {
    final id = getActiveOrderId();
    return id != null && id.isNotEmpty;
  }

  // Google Play Prominent Disclosure State
  static bool hasAgreedLocationDisclosure() =>
      _prefs?.getBool(_keyLocationDisclosureAgreed) ?? false;
  static Future<bool> setLocationDisclosureAgreed(bool agreed) async =>
      await _prefs?.setBool(_keyLocationDisclosureAgreed, agreed) ?? false;

  // Reinstall-proof persistent Device ID (Android ID on Android, iOS Keychain on iOS)
  static Future<String> initDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    String? resolvedId;

    try {
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          // androidInfo.id is Android ID (Settings.Secure.ANDROID_ID)
          // Scoped to signing key and persists across uninstalls/reinstalls on Android 8.0+
          if (androidInfo.id.isNotEmpty && androidInfo.id.toLowerCase() != 'unknown') {
            resolvedId = androidInfo.id;
          }
        } else if (Platform.isIOS) {
          // iOS Keychain persists even after complete app uninstallation
          const secureStorage = FlutterSecureStorage();
          resolvedId = await secureStorage.read(key: _keyDeviceId);
          if (resolvedId == null || resolvedId.isEmpty) {
            resolvedId = _prefs?.getString(_keyDeviceId) ?? _generateDeviceId();
            await secureStorage.write(key: _keyDeviceId, value: resolvedId);
          }
        }
      }
    } catch (_) {
      // Graceful fallback for test runners or environments without native platform channels
    }

    // Fallback to cached SharedPreferences or generate fresh UUID
    resolvedId ??= _prefs?.getString(_keyDeviceId);
    if (resolvedId == null || resolvedId.isEmpty) {
      resolvedId = _generateDeviceId();
    }

    _cachedDeviceId = resolvedId;
    await _prefs?.setString(_keyDeviceId, resolvedId);
    return resolvedId;
  }

  static String getDeviceId() {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }
    var id = _prefs?.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      id = _generateDeviceId();
      _prefs?.setString(_keyDeviceId, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  static Future<bool> setDeviceId(String deviceId) async {
    _cachedDeviceId = deviceId;
    try {
      if (!kIsWeb && Platform.isIOS) {
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: _keyDeviceId, value: deviceId);
      }
    } catch (_) {}
    return await _prefs?.setString(_keyDeviceId, deviceId) ?? false;
  }

  static String _generateDeviceId() {
    final rand = Random.secure();
    final values = List<int>.generate(16, (i) => rand.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // RFC 4122 version 4
    values[8] = (values[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-${hex.sublist(10, 16).join()}';
  }

  static Future<void> clearSession() async {
    _cachedActiveOrderId = null;
    await _prefs?.remove(_keyToken);
    await _prefs?.remove(_keyDriverId);
    await _prefs?.remove(_keyDriverName);
    await _prefs?.remove(_keyDriverPhone);
    await _prefs?.remove(_keyDriverEmail);
    await _prefs?.remove(_keyDriverAvatar);
    await _prefs?.remove(_keyIsOnline);
    await _prefs?.remove(_keyActiveOrderId);
    await _prefs?.remove(_keyLocationDisclosureAgreed);
    await _prefs?.remove(_keyDriverVehicleId);
    await _prefs?.remove(_keyDriverPlateNumber);
    await _prefs?.remove(_keyDriverCityId);
    await _prefs?.remove(_keyDriverVehicleName);
    await _prefs?.remove(_keyDriverVehicleImage);
    await _prefs?.remove(_keyDriverPickupKmPrice);
    await _prefs?.remove(_keyDriverPickupStartPrice);
  }
}
