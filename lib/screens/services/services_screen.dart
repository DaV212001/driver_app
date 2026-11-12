import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/driver_dashboard_controller.dart';
import '../../core/theme/app_colors.dart';

class ServicesScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const ServicesScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DriverDashboardController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              )
            : null,
        title: const Text(
          'Services',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        final services = controller.enabledServices;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: services.entries.map((entry) {
            final serviceName = entry.key;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    serviceName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.onlineGreenBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: AppColors.onlineGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      }),
    );
  }
}
