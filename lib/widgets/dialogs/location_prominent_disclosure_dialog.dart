import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_colors.dart';

/// Google Play compliant Prominent Disclosure Dialog for background location access.
///
/// Google Play Policy requires:
/// 1. Prominent disclosure MUST be shown before the Android runtime permission prompt.
/// 2. Must clearly explain that location is collected "even when the app is closed or not in use".
/// 3. Must explain why: real-time delivery tracking, customer ETA updates, and dispatching nearby orders.
/// 4. Must require an affirmative user action (tapping "Agree & Continue").
class LocationProminentDisclosureDialog extends StatelessWidget {
  const LocationProminentDisclosureDialog({super.key});

  /// Shows the prominent disclosure dialog. Returns true if user agreed, false otherwise.
  static Future<bool> show() async {
    // Avoid blocking automated test environments
    if (kIsWeb || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }

    if (Get.context == null) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (Get.context == null) return false;
    }

    // Do not show duplicate dialogs if already visible
    if (Get.isDialogOpen == true) {
      return false;
    }

    final result = await Get.dialog<bool>(
      const LocationProminentDisclosureDialog(),
      barrierDismissible: false,
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Title
            const Text(
              'Location Access for Deliveries',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),

            // Prominent Disclosure Core Statement
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              child: RichText(
                textAlign: TextAlign.left,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.onSurface,
                    height: 1.45,
                  ),
                  children: [
                    TextSpan(
                      text: 'AMN Driver ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text:
                          'collects location data to enable real-time delivery tracking, customer arrival estimates (ETA), and dispatching nearby orders ',
                    ),
                    TextSpan(
                      text: 'even when the app is closed or not in use.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Bullet Points for Clarification
            _buildFeaturePoint(
              icon: Icons.navigation_outlined,
              title: 'Hands-Free Navigation',
              description:
                  'Keeps tracking active when you switch to navigation apps or turn off your screen.',
            ),
            const SizedBox(height: 10),
            _buildFeaturePoint(
              icon: Icons.access_time_rounded,
              title: 'Live ETA & Customer Updates',
              description:
                  'Provides customers and dispatchers with live, accurate delivery arrival times.',
            ),
            const SizedBox(height: 10),
            _buildFeaturePoint(
              icon: Icons.security_rounded,
              title: 'Privacy Guaranteed',
              description:
                  'Location is strictly used for active order delivery and is never sold to advertisers.',
            ),
            const SizedBox(height: 22),

            // Action Buttons
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Agree & Continue',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Get.back(result: false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                foregroundColor: AppColors.onSurfaceVariant,
              ),
              child: const Text(
                'Not Now',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePoint({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
