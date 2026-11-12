import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../config/dio_config.dart';
import '../config/storage_config.dart';
import '../constants/pages.dart';
import '../models/delivery_task.dart';
import '../services/driver_order_service.dart';

class HistoryController extends GetxController {
  final RxList<DeliveryTask> historyTasks = <DeliveryTask>[].obs;
  final RxString searchQuery = ''.obs;
  final RxString selectedFilter = 'All'.obs;
  final RxBool isLoading = false.obs;

  // Order Type Filter ('All', 'Delivery', 'Corporate', 'Pickup')
  final RxString selectedOrderType = 'All'.obs;
  final List<String> orderTypeOptions = const [
    'All',
    'Delivery',
    'Corporate',
    'Pickup',
  ];

  // Date Range Filter Preset ('Today', 'This Week', 'This Month', 'All Time')
  final RxString selectedDatePreset = 'This Month'.obs;
  final List<String> datePresetOptions = const [
    'Today',
    'This Week',
    'This Month',
    'All Time',
  ];

  late final Rx<DateTime> filterStartDate;
  late final Rx<DateTime> filterEndDate;

  // Lifetime Courier Performance Metrics
  final RxInt totalLifetimeTrips = 0.obs;
  final RxDouble totalLifetimeEarnings = 0.0.obs;
  final RxDouble courierRating = 5.0.obs;

  final List<String> filterOptions = const [
    'All',
    'Today',
    'This Week',
    'Completed',
    'Cancelled',
  ];

  HistoryController() {
    _initDateRange();
    loadHistory();
  }

  void _initDateRange() {
    final now = DateTime.now();
    filterEndDate = now.obs;
    // Default to start of current month
    filterStartDate = DateTime(now.year, now.month, 1).obs;
  }

  @override
  void onInit() {
    super.onInit();
    loadHistory();
    if (!DioConfig.isTestMode) {
      fetchHistoryFromApi();
    }
  }

  void loadHistory() {
    // API-backed: history is populated via fetchHistoryFromApi()
  }

  /// Sets date preset ('Today', 'This Week', 'This Month', 'All Time')
  void setDatePreset(String preset) {
    selectedDatePreset.value = preset;
    final now = DateTime.now();
    filterEndDate.value = now;

    switch (preset) {
      case 'Today':
        filterStartDate.value = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        filterStartDate.value = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        break;
      case 'This Month':
        filterStartDate.value = DateTime(now.year, now.month, 1);
        break;
      case 'All Time':
      default:
        filterStartDate.value = now.subtract(const Duration(days: 90));
        break;
    }

    if (!DioConfig.isTestMode) {
      fetchHistoryFromApi();
    }
  }

  /// Sets custom date range
  void setCustomDateRange(DateTime start, DateTime end) {
    filterStartDate.value = start;
    filterEndDate.value = end;
    selectedDatePreset.value = 'Custom';
    if (!DioConfig.isTestMode) {
      fetchHistoryFromApi();
    }
  }

  /// Changes the order category ('All', 'Delivery', 'Corporate', 'Pickup')
  void setOrderType(String type) {
    selectedOrderType.value = type;
    if (!DioConfig.isTestMode) {
      fetchHistoryFromApi();
    }
  }

  /// Fetch history from backend using the dedicated order history endpoints:
  /// - GET /driver-order-history/$startDate/$endDate/$driverId (Standard Delivery)
  /// - GET /driver-company-order-history/$startDate/$endDate/$driverId (Corporate)
  /// - GET /driver-pickup-order-history/$startDate/$endDate/$driverId (Pickup)
  Future<void> fetchHistoryFromApi() async {
    final driverId = StorageConfig.getDriverId() ?? '1';
    final startDateStr = DateFormat('yyyy-MM-dd').format(filterStartDate.value);
    final endDateStr = DateFormat('yyyy-MM-dd').format(filterEndDate.value);

    isLoading.value = true;
    try {
      final List<DeliveryTask> collected = [];

      if (selectedOrderType.value == 'Delivery') {
        final orders = await DriverOrderService.fetchDriverOrderHistory(
          startDate: startDateStr,
          endDate: endDateStr,
          driverId: driverId,
        );
        collected.addAll(orders);
      } else if (selectedOrderType.value == 'Corporate') {
        final orders = await DriverOrderService.fetchDriverCompanyOrderHistory(
          startDate: startDateStr,
          endDate: endDateStr,
          driverId: driverId,
        );
        collected.addAll(orders);
      } else if (selectedOrderType.value == 'Pickup') {
        final orders = await DriverOrderService.fetchDriverPickupOrderHistory(
          startDate: startDateStr,
          endDate: endDateStr,
          driverId: driverId,
        );
        collected.addAll(orders);
      } else {
        // 'All' - Fetch all three history endpoints concurrently
        final results = await Future.wait([
          DriverOrderService.fetchDriverOrderHistory(
            startDate: startDateStr,
            endDate: endDateStr,
            driverId: driverId,
          ),
          DriverOrderService.fetchDriverCompanyOrderHistory(
            startDate: startDateStr,
            endDate: endDateStr,
            driverId: driverId,
          ),
          DriverOrderService.fetchDriverPickupOrderHistory(
            startDate: startDateStr,
            endDate: endDateStr,
            driverId: driverId,
          ),
        ]);

        for (final list in results) {
          collected.addAll(list);
        }

        // If specific date endpoints return no records, fallback to legacy past orders
        if (collected.isEmpty) {
          final legacyOrders = await DriverOrderService.fetchPastOrders(driverId);
          collected.addAll(legacyOrders);
        }
      }

      if (collected.isNotEmpty) {
        // Deduplicate by ID
        final Map<String, DeliveryTask> uniqueMap = {};
        for (final task in collected) {
          uniqueMap[task.id] = task;
        }

        final sorted = uniqueMap.values.toList()
          ..sort((a, b) {
            final dateA = a.completedAt ?? a.createdAt;
            final dateB = b.completedAt ?? b.createdAt;
            return dateB.compareTo(dateA);
          });

        historyTasks.assignAll(sorted);
        totalLifetimeTrips.value = sorted.length;
        final earnings = sorted.fold<double>(
          0.0,
          (sum, t) => sum + t.totalPayout,
        );
        totalLifetimeEarnings.value = earnings;
      } else {
        // API returned zero trips for this filter/period
        historyTasks.clear();
        totalLifetimeTrips.value = 0;
        totalLifetimeEarnings.value = 0.0;
      }
    } catch (_) {
      // In production/API-backed mode, do not inject mock orders on error
    } finally {
      isLoading.value = false;
    }
  }

  void addCompletedDelivery(DeliveryTask task) {
    historyTasks.insert(0, task);
    totalLifetimeTrips.value++;
    totalLifetimeEarnings.value += task.totalPayout;
  }

  List<DeliveryTask> get filteredHistory {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));

    List<DeliveryTask> list = historyTasks;

    // Filter by order type if loaded from local cache
    if (selectedOrderType.value == 'Delivery') {
      list = list.where((t) => !t.isCorporate && !t.isPickup).toList();
    } else if (selectedOrderType.value == 'Corporate') {
      list = list.where((t) => t.isCorporate).toList();
    } else if (selectedOrderType.value == 'Pickup') {
      list = list.where((t) => t.isPickup).toList();
    }

    // Filter chip logic
    if (selectedFilter.value == 'Today') {
      list = list.where((t) {
        final date = t.completedAt ?? t.createdAt;
        return date.isAfter(todayStart);
      }).toList();
    } else if (selectedFilter.value == 'This Week') {
      list = list.where((t) {
        final date = t.completedAt ?? t.createdAt;
        return date.isAfter(weekStart);
      }).toList();
    } else if (selectedFilter.value == 'Completed') {
      list = list.where((t) => t.status == DeliveryStatus.delivered).toList();
    } else if (selectedFilter.value == 'Cancelled') {
      list = list.where((t) => t.status == DeliveryStatus.cancelled).toList();
    }

    // Search query filter
    if (searchQuery.value.trim().isNotEmpty) {
      final q = searchQuery.value.toLowerCase().trim();
      list = list
          .where((t) =>
              t.orderNumber.toLowerCase().contains(q) ||
              t.storeName.toLowerCase().contains(q) ||
              t.customerName.toLowerCase().contains(q) ||
              t.customerAddress.toLowerCase().contains(q))
          .toList();
    }

    return list;
  }

  Map<String, List<DeliveryTask>> get groupedHistory {
    final Map<String, List<DeliveryTask>> groups = {};
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    for (final task in filteredHistory) {
      final taskDate = task.completedAt ?? task.createdAt;
      String groupTitle;

      if (taskDate.isAfter(todayStart)) {
        groupTitle = 'Today, ${DateFormat('MMM d').format(now)}';
      } else if (taskDate.isAfter(yesterdayStart)) {
        groupTitle = 'Yesterday, ${DateFormat('MMM d').format(yesterdayStart)}';
      } else {
        groupTitle = DateFormat('EEEE, MMM d').format(taskDate);
      }

      groups.putIfAbsent(groupTitle, () => []).add(task);
    }

    return groups;
  }

  Map<String, List<DeliveryTask>> get groupedByMonth {
    final Map<String, List<DeliveryTask>> groups = {};
    for (final task in filteredHistory) {
      final taskDate = task.completedAt ?? task.createdAt;
      final monthTitle = DateFormat('MMMM yyyy').format(taskDate);
      groups.putIfAbsent(monthTitle, () => []).add(task);
    }
    return groups;
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
  }

  void openOrderDetail(DeliveryTask task) {
    Get.toNamed(Pages.orderDetail, arguments: task);
  }

  Future<void> refreshHistory() async {
    if (DioConfig.isTestMode) {
      loadHistory();
      return;
    }
    await fetchHistoryFromApi();
  }
}
