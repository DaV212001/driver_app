import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../constants/pages.dart';
import '../../controllers/history_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../models/delivery_task.dart';

class DeliveryHistoryScreen extends StatelessWidget {
  const DeliveryHistoryScreen({super.key});

  Future<void> _selectCustomDateRange(BuildContext context, HistoryController controller) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: controller.filterStartDate.value,
        end: controller.filterEndDate.value,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.setCustomDateRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HistoryController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        title: const Text(
          'Trip history',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Filter by Date Range',
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            onPressed: () => _selectCustomDateRange(context, controller),
          ),
          Obx(() {
            final isDarkMode = ThemeController.to.isDarkMode;
            return IconButton(
              icon: Icon(
                isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 20,
                color: isDarkMode ? AppColors.starGold : AppColors.onSurfaceVariant,
              ),
              onPressed: ThemeController.to.toggleTheme,
            );
          }),
        ],
      ),
      body: Obx(() {
        final monthGroups = controller.groupedByMonth;
        final startDateStr = DateFormat('MMM d, yyyy').format(controller.filterStartDate.value);
        final endDateStr = DateFormat('MMM d, yyyy').format(controller.filterEndDate.value);

        return RefreshIndicator(
          onRefresh: controller.refreshHistory,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // 1. Search Bar
              Container(
                height: 42,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (val) => controller.searchQuery.value = val,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Search trips...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              // 2. Order Type Tabs (All, Standard Delivery, Corporate, Pickup)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: controller.orderTypeOptions.map((type) {
                    final isSelected = controller.selectedOrderType.value == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
                      child: ChoiceChip(
                        label: Text(
                          type == 'Delivery' ? 'Standard' : type,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (_) => controller.setOrderType(type),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // 3. Date Presets Row (Today, This Week, This Month, All Time)
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: controller.datePresetOptions.map((preset) {
                          final isSelected = controller.selectedDatePreset.value == preset;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 8),
                            child: FilterChip(
                              label: Text(
                                preset,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: AppColors.primaryContainer.withValues(alpha: 0.35),
                              backgroundColor: Colors.transparent,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onSelected: (_) => controller.setDatePreset(preset),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),

              // Active Date Range Indicator
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$startDateStr  –  $endDateStr',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (controller.isLoading.value)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                  ],
                ),
              ),

              if (controller.isLoading.value && controller.historyTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (monthGroups.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 56,
                        color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No trips found',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try selecting a different date range or category.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...monthGroups.entries.map((entry) {
                  final monthTitle = entry.key;
                  final tasks = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month Section Header
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 10, left: 4),
                        child: Text(
                          monthTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      // Trip List Items
                      ...tasks.map((task) {
                        final taskDate = task.completedAt ?? task.createdAt;
                        final dateStr = DateFormat('dd MMM, hh:mm a').format(taskDate);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Get.toNamed(Pages.tripDetail, arguments: task),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  // Leading Icon (Different icon/color for Corporate vs Pickup vs Standard)
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: task.isCorporate
                                        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                        : task.isPickup
                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                    child: Icon(
                                      task.isCorporate
                                          ? Icons.business_rounded
                                          : task.isPickup
                                              ? Icons.storefront_rounded
                                              : Icons.directions_car_rounded,
                                      color: task.isCorporate
                                          ? const Color(0xFF6366F1)
                                          : task.isPickup
                                              ? const Color(0xFFD97706)
                                              : AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Trip Location, Date, and Category Badge
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                task.customerAddress,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Category Pill Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: task.isCorporate
                                                    ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                                    : task.isPickup
                                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                                        : AppColors.primaryContainer.withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                task.orderTypeLabel,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: task.isCorporate
                                                      ? const Color(0xFF6366F1)
                                                      : task.isPickup
                                                          ? const Color(0xFFD97706)
                                                          : AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Amount and Status
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'ETB ${task.totalPayout.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        task.status == DeliveryStatus.cancelled
                                            ? 'Cancelled'
                                            : 'Successful',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: task.status == DeliveryStatus.cancelled
                                              ? AppColors.secondary
                                              : AppColors.onlineGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
            ],
          ),
        );
      }),
    );
  }
}
