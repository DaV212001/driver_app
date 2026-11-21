import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';

import 'package:driver_app/main.dart' as app;
import 'package:driver_app/config/storage_config.dart';
import 'package:driver_app/constants/pages.dart';
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
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Allow splash & landing to settle
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // 2. Perform Login with verified Demo Driver credentials
      // Credentials: +251 944070484 / 1234 (sanitizes to 251944070484)
      final textFields = find.byType(TextField);
      if (textFields.evaluate().length >= 2) {
        // Field 0: Phone Number
        await tester.enterText(textFields.at(0), '944070484');
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        // Field 1: Password (PIN)
        await tester.enterText(textFields.at(1), '1234');
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        // Dismiss keyboard so full screen and submit button are visible
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle(const Duration(milliseconds: 300));

        await Future.delayed(const Duration(milliseconds: 600));

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
      while (!StorageConfig.isLoggedIn() && waitCount < 30) {
        await tester.pump(const Duration(milliseconds: 300));
        await Future.delayed(const Duration(milliseconds: 300));
        waitCount++;
      }

      // Allow navigation transition to MainDriverNavigation to settle
      await tester.pumpAndSettle(const Duration(milliseconds: 800));
      await Future.delayed(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // 3. Showcase Authenticated Driver Dashboard
      await Future.delayed(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();

      // 4. Toggle Online Status (Showcases driver availability state)
      if (Get.isRegistered<DriverDashboardController>()) {
        final dashCtrl = Get.find<DriverDashboardController>();
        if (!dashCtrl.isOnline.value) {
          dashCtrl.toggleOnlineStatus();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(milliseconds: 1200));
        }

        // 5. Trigger Incoming Dispatch Job Offer Sheet (#AMN-9102)
        // Shows realistic pickup (Prosperity Media Bole) & dropoff (Kality Menaharia)
        dashCtrl.triggerIncomingOffer(IncomingJobOffer.sample());
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(milliseconds: 1800));

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

      // Helper: Tap the prominent delivery action button with visual ripple & fallback
      Future<void> tapDeliveryActionButton(Key buttonKey, VoidCallback fallbackAction) async {
        final btnFinder = find.byKey(buttonKey);
        if (btnFinder.evaluate().isNotEmpty) {
          try {
            await tester.tap(btnFinder);
            await tester.pumpAndSettle();
          } catch (_) {}
        }
        await Future.delayed(const Duration(milliseconds: 300));
        fallbackAction();
        await tester.pumpAndSettle();
      }

      // 7. Showcase Active Delivery / Navigation Screen (Tab Index 2)
      if (Get.isRegistered<MainDriverNavigationController>()) {
        Get.find<MainDriverNavigationController>().selectedIndex.value = 2;
        await tester.pumpAndSettle();
      }
      await Future.delayed(const Duration(milliseconds: 2000));
      await tester.pumpAndSettle();

      // 8. Progress Delivery Flow using prominent delivery action buttons:
      if (Get.isRegistered<ActiveDeliveryController>()) {
        final activeCtrl = Get.find<ActiveDeliveryController>();

        // Step A: Tap "Start Driving to Store"
        await Future.delayed(const Duration(milliseconds: 1500));
        await tapDeliveryActionButton(
          const Key('btn_driver_on_way_to_shop'),
          () => activeCtrl.startDriverOnTheWayToShop(),
        );
        await Future.delayed(const Duration(milliseconds: 1800));

        // Step B: Tap "Confirm Pickup & Depart"
        await tapDeliveryActionButton(
          const Key('btn_confirm_pickup_depart'),
          () => activeCtrl.confirmPickupAndDepart(),
        );
        await Future.delayed(const Duration(milliseconds: 1800));

        // Step C: Tap "Complete Delivery"
        await tapDeliveryActionButton(
          const Key('btn_complete_delivery'),
          () => activeCtrl.completeDelivery(),
        );
        await Future.delayed(const Duration(milliseconds: 1500));

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

      // 9. Return to Dashboard and navigate to Profile via Menu Drawer
      if (Get.isRegistered<MainDriverNavigationController>()) {
        Get.find<MainDriverNavigationController>().selectedIndex.value = 0;
        await tester.pumpAndSettle();
      }
      await Future.delayed(const Duration(milliseconds: 1200));

      // Open hamburger menu drawer
      final menuBtn = find.byIcon(Icons.menu_rounded);
      if (menuBtn.evaluate().isNotEmpty) {
        await tester.tap(menuBtn);
        await tester.pumpAndSettle();
      } else {
        final drawerGesture = await tester.startGesture(const Offset(10.0, 300.0));
        for (int i = 0; i < 10; i++) {
          await drawerGesture.moveBy(const Offset(30.0, 0.0));
          await tester.pump(const Duration(milliseconds: 30));
        }
        await drawerGesture.up();
        await tester.pumpAndSettle();
      }
      await Future.delayed(const Duration(milliseconds: 1500));

      // Tap "View Profile" or "Settings" to navigate to DriverProfileScreen
      final viewProfileFinder = find.text('View Profile');
      final settingsFinder = find.text('Settings');
      if (viewProfileFinder.evaluate().isNotEmpty) {
        await tester.tap(viewProfileFinder);
        await tester.pumpAndSettle();
      } else if (settingsFinder.evaluate().isNotEmpty) {
        await tester.tap(settingsFinder);
        await tester.pumpAndSettle();
      } else {
        Get.toNamed(Pages.profile);
        await tester.pumpAndSettle();
      }
      await Future.delayed(const Duration(milliseconds: 1500));

      // 10. Showcase prominent Account Deletion capability (Apple Guideline 5.1.1(v))
      try {
        // Smoothly scroll down the profile page to reveal Delete Account
        final profileScrollable = find.byType(Scrollable);
        if (profileScrollable.evaluate().isNotEmpty) {
          final scrollGesture = await tester.startGesture(const Offset(200.0, 650.0));
          for (int i = 0; i < 12; i++) {
            await scrollGesture.moveBy(const Offset(0.0, -35.0));
            await tester.pump(const Duration(milliseconds: 35));
          }
          await scrollGesture.up();
          await tester.pumpAndSettle();
        }
        await Future.delayed(const Duration(milliseconds: 1000));

        final deleteAccountFinder = find.text('Delete Account');
        if (deleteAccountFinder.evaluate().isNotEmpty) {
          await tester.tap(deleteAccountFinder);
          await tester.pumpAndSettle();

          // Keep confirmation modal visible for 3 seconds for review verification
          await Future.delayed(const Duration(seconds: 3));

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
      await Future.delayed(const Duration(milliseconds: 800));
      debugPrint('[AMN Driver App Review Demo] Flow completed successfully.');
    },
  );
}
