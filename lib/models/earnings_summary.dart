import 'delivery_task.dart';

class DailyEarning {
  final String dayName; // Mon, Tue, etc.
  final double amount; // In ETB
  final int tripCount;

  DailyEarning({
    required this.dayName,
    required this.amount,
    required this.tripCount,
  });
}

class CompletedDeliveryRecord {
  final String orderNumber;
  final String storeName;
  final String destinationArea;
  final double payoutAmount; // In ETB
  final double tipAmount; // In ETB
  final DateTime completedAt;
  final DeliveryTask? task;

  CompletedDeliveryRecord({
    required this.orderNumber,
    required this.storeName,
    required this.destinationArea,
    required this.payoutAmount,
    this.tipAmount = 0.0,
    required this.completedAt,
    this.task,
  });

  double get totalPayout => payoutAmount + tipAmount;

  // Convert to full DeliveryTask for the OrderDetailScreen if needed
  DeliveryTask toDeliveryTask() {
    if (task != null) return task!;
    return DeliveryTask(
      id: 'TSK-$orderNumber',
      orderNumber: orderNumber,
      storeName: storeName,
      storeCategory: 'Partner Store',
      storeAddress: '$storeName, Addis Ababa',
      storeDistanceKm: 2.1,
      customerName: 'Customer',
      customerPhone: '+251 91 100 2233',
      customerAddress: destinationArea,
      customerDistanceKm: 3.4,
      payoutAmount: payoutAmount,
      tipAmount: tipAmount,
      items: [
        DeliveryItemCheck(name: 'Completed Order Items', quantity: 1, isChecked: true),
      ],
      status: DeliveryStatus.delivered,
      createdAt: completedAt.subtract(const Duration(minutes: 40)),
      completedAt: completedAt,
    );
  }
}

class EarningsSummary {
  final double availableBalance; // In ETB
  final double todayEarnings; // In ETB
  final int todayDeliveries;
  final double todayOnlineHours;
  final double todayTips; // In ETB
  final List<DailyEarning> weeklyBreakdown;
  final List<CompletedDeliveryRecord> recentCompleted;

  EarningsSummary({
    required this.availableBalance,
    required this.todayEarnings,
    required this.todayDeliveries,
    required this.todayOnlineHours,
    required this.todayTips,
    required this.weeklyBreakdown,
    required this.recentCompleted,
  });

  factory EarningsSummary.empty() => EarningsSummary(
        availableBalance: 0.0,
        todayEarnings: 0.0,
        todayDeliveries: 0,
        todayOnlineHours: 0.0,
        todayTips: 0.0,
        weeklyBreakdown: const [],
        recentCompleted: const [],
      );
}
