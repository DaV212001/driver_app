import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';

import 'package:driver_app/main.dart' as app;
import 'package:driver_app/config/storage_config.dart';
import 'package:driver_app/controllers/driver_dashboard_controller.dart';
import 'package:driver_app/controllers/active_delivery_controller.dart';
import 'package:driver_app/models/incoming_job_offer.dart';
import 'package:driver_app/screens/main_driver_navigation.dart';
import 'package:driver_app/services/notification_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'App Store Review Full Demo Flow (Login, Dispatch, Delivery, Account Deletion)',
    (WidgetTester tester) async {
      // 1. Clear previous sessions for a clean start at login
      await StorageConfig.init();
      await StorageConfig.clearSession();
      await StorageConfig.setLocationDisclosureAgreed(true);
      NotificationService.skipPermissionRequest = true;

      // Launch the application
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Allow splash & landing to settle
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 2. Perform Login with verified Demo Driver credentials
      // Credentials: +251 944070484 / 1234 (sanitizes to 251944070484)
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        // Field 0: Phone Number
        await tester.enterText(textFields.at(0), '944070484');
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Field 1: Password (PIN)
        await tester.enterText(textFields.at(1), '1234');
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        await Future.delayed(const Duration(seconds: 1));

        // Tap Sign In button
        final signInButton = find.text('Sign In to Driver App');
        if (signInButton.evaluate().isNotEmpty) {
          await tester.tap(signInButton);
        } else {
          await tester.tap(find.byType(ElevatedButton).first);
        }
        await tester.pumpAndSettle();
      }

      // Wait for live authentication with AMN backend (api.amnplc.com)
      int waitCount = 0;
      while (!StorageConfig.isLoggedIn() && waitCount < 15) {
        await tester.pump(const Duration(milliseconds: 500));
        await Future.delayed(const Duration(milliseconds: 500));
        waitCount++;
      }

      // 3. Showcase Authenticated Driver Dashboard
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // 4. Toggle Online Status (Showcases driver availability state)
      if (Get.isRegistered<DriverDashboardController>()) {
        final dashCtrl = Get.find<DriverDashboardController>();
        if (!dashCtrl.isOnline.value) {
          dashCtrl.toggleOnlineStatus();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 2));
        }

        // 5. Trigger Incoming Dispatch Job Offer Sheet (#AMN-9102)
        // Shows realistic pickup (Prosperity Media Bole) & dropoff (Kality Menaharia)
        dashCtrl.triggerIncomingOffer(IncomingJobOffer.sample());
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 4));

        // 6. Accept the incoming job offer
        final acceptBtn = find.text('Accept job');
        if (acceptBtn.evaluate().isNotEmpty) {
          await tester.tap(acceptBtn);
          await tester.pumpAndSettle();
        } else {
          dashCtrl.acceptIncomingOffer();
          await tester.pumpAndSettle();
        }
      }

      // 7. Showcase Active Delivery / Navigation Screen (Tab Index 2)
      if (Get.isRegistered<MainDriverNavigationController>()) {
        Get.find<MainDriverNavigationController>().selectedIndex.value = 2;
        await tester.pumpAndSettle();
      }
      await Future.delayed(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // 8. Progress Delivery Flow:
      // Step A: Confirm pickup at store & depart toward customer
      if (Get.isRegistered<ActiveDeliveryController>()) {
        final activeCtrl = Get.find<ActiveDeliveryController>();
        activeCtrl.confirmPickupAndDepart();
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 4));

        // Step B: Complete Delivery to Customer
        activeCtrl.completeDelivery();
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));

        // Dismiss completion dialog if visible
        final doneBtn = find.text('Done');
        if (doneBtn.evaluate().isNotEmpty) {
          await tester.tap(doneBtn);
          await tester.pumpAndSettle();
        } else if (Get.isDialogOpen ?? false) {
          Get.back();
          await tester.pumpAndSettle();
        }
      }

      // 9. Switch to Profile tab (Index 3) to satisfy Apple Guideline 5.1.1(v)
      if (Get.isRegistered<MainDriverNavigationController>()) {
        Get.find<MainDriverNavigationController>().selectedIndex.value = 3;
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
      }

      // 10. Showcase prominent Account Deletion capability
      try {
        final deleteAccountFinder = find.text('Delete Account');
        final scrollableFinder = find.byType(Scrollable);
        if (scrollableFinder.evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(
            deleteAccountFinder,
            150,
            scrollable: scrollableFinder.first,
          );
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        }

        if (deleteAccountFinder.evaluate().isNotEmpty) {
          await tester.tap(deleteAccountFinder);
          await tester.pumpAndSettle();

          // Keep confirmation modal visible for 4 seconds for review verification
          await Future.delayed(const Duration(seconds: 4));

          // Dismiss modal to keep demo account active
          final cancelFinder = find.text('Cancel');
          if (cancelFinder.evaluate().isNotEmpty) {
            await tester.tap(cancelFinder);
            await tester.pumpAndSettle();
          } else if (Get.isDialogOpen ?? false) {
            Get.back();
            await tester.pumpAndSettle();
          }
        }
      } catch (e) {
        debugPrint('[AMN Demo] Account deletion interaction notice: $e');
      }

      // Conclude demo cleanly
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('[AMN Driver App Review Demo] Flow completed successfully.');
    },
  );
}
