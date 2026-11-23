import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/currency_utils.dart';

class BottomPerformanceCard extends StatelessWidget {
  final double todayEarnings;
  final double walletBalance;
  final String? currency;
  final int profileScore;
  final double rating;
  final int cancellationRate;
  final int assignedCount;
  final VoidCallback? onWalletTap;
  final VoidCallback? onAssignedTap;

  const BottomPerformanceCard({
    super.key,
    required this.todayEarnings,
    required this.walletBalance,
    this.currency,
    required this.profileScore,
    required this.rating,
    required this.cancellationRate,
    this.assignedCount = 4,
    this.onWalletTap,
    this.onAssignedTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: borderCol, width: 1.5),
          left: BorderSide(color: borderCol, width: 1.5),
          right: BorderSide(color: borderCol, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Top subtle drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Earnings and Wallet Balance Row (Photo 1)
          Row(
            children: [
              // Today's earning
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Earnings",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AutoSizeText(
                      CurrencyUtils.format(todayEarnings, currency: currency),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),

              // Wallet balance
              Expanded(
                child: InkWell(
                  onTap: onWalletTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Wallet balance',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AutoSizeText(
                        CurrencyUtils.format(walletBalance, currency: currency, decimalDigits: 1),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. Three KPI Scorecards (Profile Score, Rating, Cancellation)
          Row(
            children: [
              // Profile Score
              Expanded(
                child: _KpiMetricCard(
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.onlineGreen,
                  value: '$profileScore%',
                  label: 'Profile Score',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),

              // Rating
              Expanded(
                child: _KpiMetricCard(
                  icon: Icons.star_rounded,
                  iconColor: AppColors.starGold,
                  value: rating.toStringAsFixed(1),
                  label: 'Rating',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),

              // Cancellation
              Expanded(
                child: _KpiMetricCard(
                  icon: Icons.cancel_rounded,
                  iconColor: AppColors.secondary,
                  value: '$cancellationRate%',
                  label: 'Cancellation',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
  }
}

class _KpiMetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool isDark;

  const _KpiMetricCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 3),
              Flexible(
                child: AutoSizeText(
                  value,
                  maxLines: 1,
                  minFontSize: 9,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AutoSizeText(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            minFontSize: 8,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
