import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../constants/constants.dart';
import '../../constants/pages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../controllers/earnings_controller.dart';

class EarningsScreen extends StatelessWidget {
  final VoidCallback? onBack;
  const EarningsScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EarningsController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              )
            : null,
        title: const AutoSizeText(
          'Earnings & Payouts',
          maxLines: 1,
          minFontSize: 14,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          Obx(() {
            final isDark = ThemeController.to.isDarkMode;
            return IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
                color: isDark ? AppColors.starGold : AppColors.onSurfaceVariant,
              ),
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              onPressed: ThemeController.to.toggleTheme,
            );
          }),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Complete Delivery History',
            onPressed: () => Get.toNamed(Pages.deliveryHistory),
          ),
        ],
      ),
      body: Obx(() {
        final earnings = controller.earnings.value;

        return RefreshIndicator(
          onRefresh: () async {
            await controller.fetchWalletAndEarnings();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Total Balance Card (ETB) - AutoSizeText for clean fit
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        Color(0xFF007BBB),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: AutoSizeText(
                              'AVAILABLE BALANCE',
                              maxLines: 1,
                              minFontSize: 9,
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_rounded,
                                    size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'CBE / Telebirr',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AutoSizeText(
                        formatEtb(earnings.availableBalance),
                        maxLines: 1,
                        minFontSize: 18,
                        style: textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: controller.isCashingOut.value
                              ? null
                              : controller.cashOut,
                          icon: controller.isCashingOut.value
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        AppColors.primary),
                                  ),
                                )
                              : const Icon(Icons.send_to_mobile_rounded,
                                  color: AppColors.primary),
                          label: AutoSizeText(
                            controller.isCashingOut.value
                                ? 'Processing Transfer...'
                                : 'Cash Out Now',
                            maxLines: 1,
                            minFontSize: 11,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Weekly Breakdown Bar Chart
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: AutoSizeText(
                              'Weekly Earnings',
                              maxLines: 1,
                              minFontSize: 11,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'This Week',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Bar Chart Graphic
                      SizedBox(
                        height: 130,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: earnings.weeklyBreakdown.map((day) {
                            const maxAmount = 2400.0;
                            final barRatio =
                                (day.amount / maxAmount).clamp(0.1, 1.0);
                            final isToday = day.dayName == 'Sun';

                            return Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(day.amount / 1000).toStringAsFixed(1)}k',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isToday
                                          ? AppColors.primary
                                          : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 80 * barRatio,
                                    width: 18,
                                    decoration: BoxDecoration(
                                      color: isToday
                                          ? AppColors.primary
                                          : AppColors.primaryContainer.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    day.dayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isToday
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isToday
                                          ? AppColors.primary
                                          : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Performance Metrics Cards
                Row(
                  children: [
                    _buildMetricCard(
                      context,
                      title: 'Deliveries',
                      value: '${earnings.todayDeliveries}',
                      icon: Icons.inventory_2_rounded,
                      iconColor: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      context,
                      title: 'Online Hours',
                      value: '${earnings.todayOnlineHours}h',
                      icon: Icons.schedule_rounded,
                      iconColor: AppColors.tertiary,
                    ),
                    const SizedBox(width: 10),
                    _buildMetricCard(
                      context,
                      title: 'Avg / Trip',
                      value: formatEtb(earnings.todayDeliveries > 0
                          ? (earnings.todayEarnings / earnings.todayDeliveries)
                          : 0),
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.onlineGreen,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. Recent Completed Deliveries Header with Link to Full History
                Row(
                  children: [
                    Expanded(
                      child: AutoSizeText(
                        'Recent Completed Deliveries',
                        maxLines: 1,
                        minFontSize: 11,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Get.toNamed(Pages.deliveryHistory),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...earnings.recentCompleted.map((record) {
                  return InkWell(
                    onTap: () => Get.toNamed(Pages.orderDetail, arguments: record.toDeliveryTask()),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.onlineGreenBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.onlineGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AutoSizeText(
                                  record.storeName,
                                  maxLines: 1,
                                  minFontSize: 11,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                AutoSizeText(
                                  '${record.destinationArea} • ${DateFormat('h:mm a').format(record.completedAt)}',
                                  maxLines: 1,
                                  minFontSize: 9,
                                  style: textTheme.bodySmall?.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AutoSizeText(
                                  formatEtb(record.totalPayout),
                                  maxLines: 1,
                                  minFontSize: 10,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.onSurfaceVariant),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 10),
            AutoSizeText(
              value,
              maxLines: 1,
              minFontSize: 11,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
            ),
            const SizedBox(height: 2),
            AutoSizeText(
              title,
              maxLines: 1,
              minFontSize: 9,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
