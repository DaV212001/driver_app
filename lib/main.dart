import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'bindings/initial_binding.dart';
import 'config/storage_config.dart';
import 'constants/constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'firebase_options.dart';
import 'routes/app_pages.dart';
import 'services/gebeta_location_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageConfig.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.instance.initialize();
  await GebetaLocationService.configureMapHeaders();

  runApp(const AmnDriverApp());
}

class AmnDriverApp extends StatelessWidget {
  const AmnDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = Get.put(ThemeController(), permanent: true);

    return Obx(() => GetMaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeCtrl.themeMode,
          initialBinding: InitialBinding(),
          initialRoute: AppPages.initial,
          getPages: AppPages.routes,
          defaultTransition: Transition.cupertino,
        ));
  }
}
