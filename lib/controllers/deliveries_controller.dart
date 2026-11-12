import 'package:get/get.dart';
import '../config/storage_config.dart';
import '../constants/pages.dart';
import '../models/delivery_task.dart';
import '../screens/main_driver_navigation.dart';
import '../services/driver_order_service.dart';
import '../services/notification_service.dart';
import 'active_delivery_controller.dart';

class DeliveriesController extends GetxController {
  final RxList<DeliveryTask> assignedTasks = <DeliveryTask>[].obs;
  final RxInt selectedTabIndex = 0.obs; // 0: All, 1: Active, 2: Ready for Pickup, 3: Pending
  final RxString searchQuery = ''.obs;

  DeliveriesController() {
    loadTasks();
  }

  @override
  void onInit() {
    super.onInit();
    loadTasks();
  }

  void loadTasks() {
    final driverId = StorageConfig.getDriverId();
    if (driverId != null && driverId.isNotEmpty) {
      DriverOrderService.fetchActiveOrders(driverId).then((orders) {
        assignedTasks.assignAll(orders);
      });
    } else {
      assignedTasks.clear();
    }
  }

  List<DeliveryTask> get filteredTasks {
    List<DeliveryTask> list = assignedTasks;

    // Filter by tab
    if (selectedTabIndex.value == 1) {
      // Active / In Progress
      list = list
          .where((t) =>
              t.status == DeliveryStatus.headingToStore ||
              t.status == DeliveryStatus.pickedUp)
          .toList();
    } else if (selectedTabIndex.value == 2) {
      // Ready for Pickup / At Store
      list = list.where((t) => t.status == DeliveryStatus.atStore).toList();
    } else if (selectedTabIndex.value == 3) {
      // Pending / Placed / Newly Assigned
      list = list
          .where((t) =>
              t.status == DeliveryStatus.assigned ||
              t.status == DeliveryStatus.placed)
          .toList();
    }

    // Filter by search query if any
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

  int get allCount => assignedTasks.length;
  int get activeCount => assignedTasks
      .where((t) =>
          t.status == DeliveryStatus.headingToStore ||
          t.status == DeliveryStatus.pickedUp)
      .length;
  int get readyCount =>
      assignedTasks.where((t) => t.status == DeliveryStatus.atStore).length;
  int get pendingCount => assignedTasks
      .where((t) =>
          t.status == DeliveryStatus.assigned ||
          t.status == DeliveryStatus.placed)
      .length;

  void selectTab(int index) {
    selectedTabIndex.value = index;
  }

  void startOrResumeDelivery(DeliveryTask task) {
    if (task.status == DeliveryStatus.assigned) {
      task.status = DeliveryStatus.headingToStore;
      assignedTasks.refresh();
      final orderId = task.id.replaceAll(RegExp(r'[^0-9]'), '');
      if (orderId.isNotEmpty) {
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: '2',
          task: task,
        );
      }
    }

    // Pass to ActiveDeliveryController
    if (Get.isRegistered<ActiveDeliveryController>()) {
      final activeCtrl = Get.find<ActiveDeliveryController>();
      activeCtrl.setActiveTask(task);
    }

    // Switch to Active Delivery tab (index 2 in Main navigation)
    if (Get.isRegistered<MainDriverNavigationController>()) {
      final navCtrl = Get.find<MainDriverNavigationController>();
      navCtrl.setIndex(2);
    } else {
      Get.toNamed(Pages.activeDelivery);
    }
  }

  void openOrderDetail(DeliveryTask task) {
    Get.toNamed(Pages.orderDetail, arguments: task);
  }

  Future<void> refreshDeliveries() async {
    await Future.delayed(const Duration(milliseconds: 600));
    loadTasks();
  }
}
