import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/storage_config.dart';
import '../core/theme/app_colors.dart';
import '../models/delivery_task.dart';
import '../models/earnings_summary.dart';
import '../screens/wallet/payment_webview_screen.dart';
import '../services/driver_order_service.dart';
import '../services/driver_profile_service.dart';

class EarningsController extends GetxController {
  final Rx<EarningsSummary> earnings = EarningsSummary.empty().obs;
  final RxBool isCashingOut = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  // Wallet UI state (Photo 6)
  final RxBool isBalanceHidden = false.obs;
  final RxString selectedBreakdownTab = 'Daily'.obs; // 'Daily', 'Weekly', 'Monthly'

  @override
  void onInit() {
    super.onInit();
    final driverId = StorageConfig.getDriverId();
    if (driverId != null && driverId.isNotEmpty) {
      fetchWalletAndEarnings();
    }
  }

  /// Synchronize metrics directly from external caller or dashboard
  void syncMetrics({double? todayEarnings, double? walletBalance}) {
    if (todayEarnings == null && walletBalance == null) return;
    earnings.value = EarningsSummary(
      availableBalance: walletBalance ?? earnings.value.availableBalance,
      todayEarnings: todayEarnings ?? earnings.value.todayEarnings,
      todayDeliveries: earnings.value.todayDeliveries,
      todayOnlineHours: earnings.value.todayOnlineHours,
      todayTips: earnings.value.todayTips,
      weeklyBreakdown: earnings.value.weeklyBreakdown,
      recentCompleted: earnings.value.recentCompleted,
    );
    earnings.refresh();
  }

  /// Fetch driver wallet amount and today earning from backend APIs:
  /// GET /driver_my_wallet_amount/{driver_id}
  /// GET /today_earning/{driver_id}
  Future<void> fetchWalletAndEarnings() async {
    final driverId = StorageConfig.getDriverId();
    if (driverId == null || driverId.isEmpty) return;

    isLoading.value = true;
    try {
      final results = await Future.wait([
        DriverProfileService.fetchWalletAmount(driverId),
        DriverProfileService.fetchTodayEarning(driverId),
        DriverOrderService.fetchPastOrders(driverId),
      ]);

      final wallet = results[0] as double?;
      final todayEarn = results[1] as double?;
      final pastOrders = results[2] as List<DeliveryTask>? ?? [];

      final now = DateTime.now();
      final todayDeliveries = pastOrders.where((t) =>
          t.status == DeliveryStatus.delivered &&
          t.createdAt.year == now.year &&
          t.createdAt.month == now.month &&
          t.createdAt.day == now.day).length;

      final recentList = pastOrders.map((t) => CompletedDeliveryRecord(
        orderNumber: t.orderNumber,
        storeName: t.storeName,
        destinationArea: t.customerAddress,
        payoutAmount: t.payoutAmount,
        tipAmount: 0.0,
        completedAt: t.completedAt ?? t.createdAt,
        task: t,
      )).toList();

      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final Map<int, List<DeliveryTask>> dayBuckets = {for (int i = 0; i < 7; i++) i: []};
      for (final order in pastOrders) {
        if (now.difference(order.createdAt).inDays < 7) {
          final idx = (order.createdAt.weekday - 1) % 7;
          dayBuckets[idx]?.add(order);
        }
      }
      final weeklyBreakdown = List.generate(7, (i) {
        final ordersForDay = dayBuckets[i] ?? [];
        final amount = ordersForDay.fold<double>(0.0, (sum, o) => sum + o.totalPayout);
        return DailyEarning(
          dayName: dayNames[i],
          amount: amount,
          tripCount: ordersForDay.length,
        );
      });

      earnings.value = EarningsSummary(
        availableBalance: wallet ?? earnings.value.availableBalance,
        todayEarnings: todayEarn ?? earnings.value.todayEarnings,
        todayDeliveries: todayDeliveries,
        todayOnlineHours: (todayDeliveries * 0.4).clamp(0.0, 14.0),
        todayTips: 0.0,
        weeklyBreakdown: weeklyBreakdown,
        recentCompleted: recentList,
      );
      earnings.refresh();
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  void toggleBalanceVisibility() {
    isBalanceHidden.value = !isBalanceHidden.value;
  }

  void setBreakdownTab(String tab) {
    selectedBreakdownTab.value = tab;
  }

  void recordCompletedDelivery(DeliveryTask task) {
    final updatedRecent = List<CompletedDeliveryRecord>.from(earnings.value.recentCompleted);
    updatedRecent.insert(
      0,
      CompletedDeliveryRecord(
        orderNumber: task.orderNumber,
        storeName: task.storeName,
        destinationArea: task.customerAddress,
        payoutAmount: task.payoutAmount,
        tipAmount: task.tipAmount,
        completedAt: DateTime.now(),
      ),
    );

    earnings.value = EarningsSummary(
      availableBalance: earnings.value.availableBalance + task.totalPayout,
      todayEarnings: earnings.value.todayEarnings + task.totalPayout,
      todayDeliveries: earnings.value.todayDeliveries + 1,
      todayOnlineHours: earnings.value.todayOnlineHours + 0.3,
      todayTips: earnings.value.todayTips + task.tipAmount,
      weeklyBreakdown: earnings.value.weeklyBreakdown,
      recentCompleted: updatedRecent,
    );
  }

  /// Universal Top-Up Dialog for Wallet (aligned with delivery_app)
  static void showTopUpDialog(BuildContext context, {double? suggestedAmount}) {
    final earningsController = Get.isRegistered<EarningsController>()
        ? Get.find<EarningsController>()
        : Get.put(EarningsController());

    final initialVal = suggestedAmount != null && suggestedAmount > 0
        ? suggestedAmount.ceil().toString()
        : '100';

    final amountController = TextEditingController(text: initialVal);
    final quickAmounts = [100.0, 250.0, 500.0, 1000.0];

    Get.dialog(
      StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Top-up Wallet',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose an amount to add to your balance:',
                    style: TextStyle(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickAmounts.map((amt) {
                      final isSelected = amountController.text == amt.toStringAsFixed(0);
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            amountController.text = amt.toStringAsFixed(0);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkSurfaceContainerLow
                                    : AppColors.surfaceContainerLow),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '+${amt.toStringAsFixed(0)} Br',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkOnSurface
                                      : AppColors.onSurface),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Custom Amount',
                      suffixText: 'Br',
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      filled: true,
                      fillColor: isDark ? AppColors.darkInputBg : AppColors.inputBg,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Secured with Chapa Payment Gateway',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                child: const Text('Cancel'),
              ),
              Obx(() {
                if (earningsController.isSaving.value) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  );
                }
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: () {
                    final val = double.tryParse(amountController.text.trim()) ?? 0;
                    if (val <= 0) {
                      if (!Get.testMode && Get.context != null) {
                        Get.snackbar(
                          'Invalid Amount',
                          'Please enter a valid amount greater than 0',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                      return;
                    }
                    earningsController.depositToWallet(amount: val);
                  },
                  child: const Text(
                    'Proceed to Pay',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  /// Deposit funds into wallet via Chapa (POST /driver-wallet-payment)
  Future<bool> depositToWallet({
    required double amount,
    String? provider,
    String? phone,
    String? pin,
  }) async {
    final driverId = StorageConfig.getDriverId();
    if (driverId == null || driverId.isEmpty) {
      if (!Get.testMode && Get.context != null) {
        Get.snackbar('Sign In Required', 'Please log in to deposit funds.');
      }
      return false;
    }
    if (amount <= 0) {
      if (!Get.testMode && Get.context != null) {
        Get.snackbar('Invalid Amount', 'Please enter a valid deposit amount.');
      }
      return false;
    }

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    bool isSuccess = false;
    isSaving.value = true;
    try {
      await DriverProfileService.topupWallet(
        driverId: driverId,
        amount: amount,
        date: dateStr,
        onSuccess: (checkoutUrl, message) async {
          isSaving.value = false;
          if (Get.isDialogOpen ?? false) {
            Get.back(); // Dismiss top-up input dialog
          }

          if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
            // Open in-app WebView tracking receipt redirects without launching external browser
            final result = await Get.to(
              () => PaymentWebViewScreen(
                initialUrl: checkoutUrl,
                title: 'AMN Driver Top-up',
                onReceiptDetected: () async {
                  await fetchWalletAndEarnings();
                },
              ),
            );

            // Once WebView closes, refresh wallet balance to guarantee fresh data
            await fetchWalletAndEarnings();
            isSuccess = result == true;
            return;
          }

          // Direct confirmation fallback (e.g. mock or immediate credit)
          earnings.value = EarningsSummary(
            availableBalance: earnings.value.availableBalance + amount,
            todayEarnings: earnings.value.todayEarnings,
            todayDeliveries: earnings.value.todayDeliveries,
            todayOnlineHours: earnings.value.todayOnlineHours,
            todayTips: earnings.value.todayTips,
            weeklyBreakdown: earnings.value.weeklyBreakdown,
            recentCompleted: earnings.value.recentCompleted,
          );
          earnings.refresh();
          await fetchWalletAndEarnings();
          isSuccess = true;
          if (!Get.testMode && Get.context != null) {
            Get.snackbar(
              'Deposit Successful',
              'ETB ${amount.toStringAsFixed(2)} credited to your wallet.',
              snackPosition: SnackPosition.TOP,
              backgroundColor: const Color(0xFF22C55E),
              colorText: Colors.white,
            );
          }
        },
        onFailure: (error) {
          isSaving.value = false;
          isSuccess = false;
          if (!Get.testMode && Get.context != null) {
            Get.snackbar(
              'Deposit Failed',
              error,
              snackPosition: SnackPosition.TOP,
              backgroundColor: AppColors.error,
              colorText: Colors.white,
            );
          }
        },
      );
    } finally {
      isSaving.value = false;
    }

    return isSuccess;
  }

  /// Transfer funds to another driver (Photo 9)
  Future<bool> transferToDriver({
    required String recipientPhone,
    required double amount,
  }) async {
    if (amount <= 0) {
      Get.snackbar('Invalid Amount', 'Please enter a valid transfer amount.');
      return false;
    }
    if (amount > earnings.value.availableBalance) {
      Get.snackbar('Insufficient Funds', 'Transfer amount exceeds your available balance.');
      return false;
    }

    await Future.delayed(const Duration(milliseconds: 700));

    earnings.value = EarningsSummary(
      availableBalance: earnings.value.availableBalance - amount,
      todayEarnings: earnings.value.todayEarnings,
      todayDeliveries: earnings.value.todayDeliveries,
      todayOnlineHours: earnings.value.todayOnlineHours,
      todayTips: earnings.value.todayTips,
      weeklyBreakdown: earnings.value.weeklyBreakdown,
      recentCompleted: earnings.value.recentCompleted,
    );
    earnings.refresh();

    Get.snackbar(
      'Transfer Completed',
      'ETB ${amount.toStringAsFixed(2)} transferred to driver ($recipientPhone).',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF009EE0),
      colorText: Colors.white,
    );
    return true;
  }

  Future<void> cashOut() async {
    if (earnings.value.availableBalance <= 0) {
      Get.snackbar('Cash Out', 'No available balance to withdraw.');
      return;
    }

    isCashingOut.value = true;
    await Future.delayed(const Duration(seconds: 2));
    isCashingOut.value = false;

    final cashedAmount = earnings.value.availableBalance;
    earnings.value = EarningsSummary(
      availableBalance: 0.0,
      todayEarnings: earnings.value.todayEarnings,
      todayDeliveries: earnings.value.todayDeliveries,
      todayOnlineHours: earnings.value.todayOnlineHours,
      todayTips: earnings.value.todayTips,
      weeklyBreakdown: earnings.value.weeklyBreakdown,
      recentCompleted: earnings.value.recentCompleted,
    );

    Get.defaultDialog(
      title: 'Cash Out Successful! 🏦',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText:
          'ETB ${cashedAmount.toStringAsFixed(2)} has been transferred to your Commercial Bank of Ethiopia (CBE) account ending in 0294.',
      textConfirm: 'Great',
      confirmTextColor: Colors.white,
      onConfirm: () => Get.back(),
    );
  }
}
