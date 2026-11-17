import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../constants/pages.dart';
import '../../controllers/earnings_controller.dart';
import '../../core/theme/app_colors.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EarningsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        title: const Text(
          'Wallet',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        final earnings = controller.earnings.value;
        final isHidden = controller.isBalanceHidden.value;
        final selectedTab = controller.selectedBreakdownTab.value;
        final nowFormatted = DateFormat('MMM d').format(DateTime.now());

        return RefreshIndicator(
          onRefresh: () async {
            await controller.fetchWalletAndEarnings();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // 1. Topographic Pattern Balance Card (Photo 6 in AMN Blue)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF006699)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your wallet balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isHidden
                                ? 'ETB •••••'
                                : 'ETB ${earnings.availableBalance.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              isHidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white70,
                              size: 22,
                            ),
                            onPressed: controller.toggleBalanceVisibility,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Action Buttons (Top-up active; Withdraw & Transfer commented out)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _WalletActionButton(
                          icon: Icons.add_rounded,
                          label: 'Top-up',
                          onTap: () => EarningsController.showTopUpDialog(context),
                        ),
                        /*
                        _WalletActionButton(
                          icon: Icons.south_rounded,
                          label: 'Withdraw',
                          onTap: controller.cashOut,
                        ),
                        _WalletActionButton(
                          icon: Icons.send_rounded,
                          label: 'Transfer',
                          onTap: () => Get.toNamed(Pages.walletTransfer),
                        ),
                        */
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // "See all activity ->" Link (Photo 6)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => Get.toNamed(Pages.deliveryHistory),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'See all activity',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Today's Activity Section (Photo 6)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today $nowFormatted',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (earnings.todayDeliveries == 0)
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 56,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No Trips',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "You haven't received any trip yet",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: earnings.recentCompleted.take(3).map((record) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primaryContainer,
                              child: Icon(Icons.directions_car_rounded, color: AppColors.primary),
                            ),
                            title: Text(record.destinationArea, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(DateFormat('hh:mm a').format(record.completedAt)),
                            trailing: Text(
                              'ETB ${record.totalPayout.toStringAsFixed(1)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.onlineGreen),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. Earning Breakdown Section (Photo 6)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Earning breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Segmented Tabs: Daily | Weekly | Monthly
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: ['Daily', 'Weekly', 'Monthly'].map((tab) {
                          final isSelected = selectedTab == tab;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => controller.setBreakdownTab(tab),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    tab,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                      fontSize: 13,
                                      color: isSelected
                                          ? (isDark ? Colors.white : Colors.black)
                                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Breakdown Data Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _BreakdownMetric(
                            label: selectedTab == 'Daily'
                                ? "Today's Payout"
                                : selectedTab == 'Weekly'
                                    ? 'Weekly Total'
                                    : 'Monthly Total',
                            value: 'ETB ${earnings.todayEarnings.toStringAsFixed(1)}',
                          ),
                        ),
                        Expanded(
                          child: _BreakdownMetric(
                            label: 'Trips',
                            value: '${earnings.todayDeliveries}',
                          ),
                        ),
                        Expanded(
                          child: _BreakdownMetric(
                            label: 'Online Time',
                            value: '${earnings.todayOnlineHours.toStringAsFixed(1)} hrs',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white30),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownMetric extends StatelessWidget {
  final String label;
  final String value;

  const _BreakdownMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
