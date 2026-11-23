import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../constants/constants.dart';
import '../../controllers/deliveries_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/status_badge.dart';
import '../../models/delivery_task.dart';

class AssignedDeliveriesScreen extends StatelessWidget {
  final bool showAppBar;

  const AssignedDeliveriesScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DeliveriesController>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showAppBar
          ? AppBar(
              centerTitle: false,
              title: const AutoSizeText(
                'Assigned Deliveries',
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
                Obx(() => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Center(
                        child: StatusBadge(
                          label: '${controller.assignedTasks.length} Assigned',
                          icon: Icons.assignment_turned_in_rounded,
                          backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
                          textColor: AppColors.primary,
                        ),
                      ),
                    )),
              ],
            )
          : null,
      body: Obx(() {
        final tasks = controller.filteredTasks;
        final selectedTab = controller.selectedTabIndex.value;

        return RefreshIndicator(
          onRefresh: controller.refreshDeliveries,
          child: Column(
            children: [
              // 1. Search Bar & Filter Chips Header
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: TextField(
                        onChanged: (val) => controller.searchQuery.value = val,
                        decoration: const InputDecoration(
                          hintText: 'Search order #, store, or customer...',
                          hintStyle: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                          prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.onSurfaceVariant),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterTab(
                            context,
                            index: 0,
                            label: 'All (${controller.allCount})',
                            isSelected: selectedTab == 0,
                            onTap: () => controller.selectTab(0),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterTab(
                            context,
                            index: 1,
                            label: 'Active (${controller.activeCount})',
                            isSelected: selectedTab == 1,
                            onTap: () => controller.selectTab(1),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterTab(
                            context,
                            index: 2,
                            label: 'Ready (${controller.readyCount})',
                            isSelected: selectedTab == 2,
                            onTap: () => controller.selectTab(2),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterTab(
                            context,
                            index: 3,
                            label: 'Pending (${controller.pendingCount})',
                            isSelected: selectedTab == 3,
                            onTap: () => controller.selectTab(3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 2. Deliveries List View
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              AutoSizeText(
                                'No Deliveries Found',
                                maxLines: 1,
                                minFontSize: 13,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AutoSizeText(
                                controller.searchQuery.value.isNotEmpty
                                    ? 'No orders matching "${controller.searchQuery.value}"'
                                    : 'There are currently no deliveries in this queue.',
                                maxLines: 2,
                                minFontSize: 10,
                                style: textTheme.bodySmall?.copyWith(fontSize: 11.5),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildDeliveryCard(context, task, controller);
                        },
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFilterTab(
    BuildContext context, {
    required int index,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        child: AutoSizeText(
          label,
          maxLines: 1,
          minFontSize: 10,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(
    BuildContext context,
    DeliveryTask task,
    DeliveriesController controller,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: task.status == DeliveryStatus.headingToStore ||
                  task.status == DeliveryStatus.pickedUp
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.outlineVariant,
          width: task.status == DeliveryStatus.headingToStore ||
                  task.status == DeliveryStatus.pickedUp
              ? 1.5
              : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Order # & Status Badge
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoSizeText(
                            'Order #${task.orderNumber}',
                            maxLines: 1,
                            minFontSize: 10,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          AutoSizeText(
                            task.storeCategory,
                            maxLines: 1,
                            minFontSize: 9,
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 10.5,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: StatusBadge(
                  label: task.statusLabel,
                  backgroundColor: task.statusBgColor,
                  textColor: task.statusColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Store & Customer Route Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.radio_button_checked, size: 15, color: AppColors.primary),
                  Container(
                    width: 2,
                    height: 28,
                    color: AppColors.outlineVariant,
                  ),
                  const Icon(Icons.location_on_rounded, size: 15, color: AppColors.secondary),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      '${task.storeName} (${task.storeDistanceKm} km)',
                      maxLines: 1,
                      minFontSize: 11,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.onSurface,
                      ),
                    ),
                    AutoSizeText(
                      task.storeAddress,
                      maxLines: 1,
                      minFontSize: 9,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AutoSizeText(
                      '${task.customerName} (${task.customerDistanceKm} km)',
                      maxLines: 1,
                      minFontSize: 11,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.onSurface,
                      ),
                    ),
                    AutoSizeText(
                      task.customerAddress,
                      maxLines: 1,
                      minFontSize: 9,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Payout & Items Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.onlineGreenBg.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_rounded, size: 15, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 6),
                    AutoSizeText(
                      '${task.itemCount} items',
                      maxLines: 1,
                      minFontSize: 9,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formatEtb(task.totalPayout, currency: task.currency),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onlineGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons: Start/Navigate & View Details
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => controller.openOrderDetail(task),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurfaceVariant,
                    minimumSize: const Size.fromHeight(42),
                    side: const BorderSide(color: AppColors.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const AutoSizeText(
                    'View Details',
                    maxLines: 1,
                    minFontSize: 10,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: () => controller.startOrResumeDelivery(task),
                  icon: Icon(
                    task.status == DeliveryStatus.headingToStore ||
                            task.status == DeliveryStatus.pickedUp
                        ? Icons.navigation_rounded
                        : Icons.play_arrow_rounded,
                    size: 16,
                  ),
                  label: AutoSizeText(
                    task.status == DeliveryStatus.headingToStore ||
                            task.status == DeliveryStatus.pickedUp
                        ? 'Navigate'
                        : 'Start Delivery',
                    maxLines: 1,
                    minFontSize: 9,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
