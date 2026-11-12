import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/storage_config.dart';

class ThemeController extends GetxController {
  static ThemeController get to => Get.find<ThemeController>();

  final RxBool _isDarkMode = false.obs;

  bool get isDarkMode => _isDarkMode.value;
  ThemeMode get themeMode =>
      _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    // Default is Light mode
    _isDarkMode.value = StorageConfig.isDarkMode();
  }

  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    StorageConfig.setDarkMode(_isDarkMode.value);
    Get.changeThemeMode(themeMode);
  }

  void setDarkMode(bool value) {
    if (_isDarkMode.value == value) return;
    _isDarkMode.value = value;
    StorageConfig.setDarkMode(value);
    Get.changeThemeMode(themeMode);
  }
}
