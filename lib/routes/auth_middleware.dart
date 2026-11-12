import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../config/storage_config.dart';
import '../constants/pages.dart';

/// Middleware to restrict unauthenticated access to main app pages.
/// Redirects unauthenticated users to the Login page.
class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  RouteSettings? redirect(String? route) {
    if (!StorageConfig.isLoggedIn()) {
      return const RouteSettings(name: Pages.login);
    }
    return null;
  }
}
