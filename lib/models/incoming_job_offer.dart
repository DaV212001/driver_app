import 'delivery_task.dart';
import '../utils/currency_utils.dart';

class IncomingJobOffer {
  final String id;
  final String orderNumber;
  final String pickupName;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String dropoffName;
  final String dropoffAddress;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final double surgeMultiplier;
  final double customerRating;
  final String serviceCategory;
  final String paymentMethod;
  final double fareAmount;
  final String? currency;
  final int dropoffMinutes;
  final double distanceKm;
  final int totalDurationSeconds;
  final DateTime receivedAt;
  final dynamic customerId;
  final dynamic ownerId;
  final String? propertyName;
  final String status;
  final String statusLabel;
  final String orderType;

  IncomingJobOffer({
    required this.id,
    required this.orderNumber,
    required this.pickupName,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffName,
    required this.dropoffAddress,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    this.surgeMultiplier = 1.5,
    this.customerRating = 4.5,
    this.serviceCategory = 'Economy',
    this.paymentMethod = 'Cash',
    required this.fareAmount,
    this.currency,
    required this.dropoffMinutes,
    required this.distanceKm,
    this.totalDurationSeconds = 120, // 2-minute order acceptance countdown
    DateTime? receivedAt,
    this.customerId,
    this.ownerId,
    this.propertyName,
    this.status = '0',
    this.statusLabel = 'Order Placed',
    this.orderType = 'delivery',
  }) : receivedAt = receivedAt ?? DateTime.now();

  String get displayCurrency => CurrencyUtils.resolveCode(currency);

  DeliveryTask toDeliveryTask() {
    return DeliveryTask(
      id: id,
      orderNumber: orderNumber,
      orderType: orderType,
      storeName: pickupName,
      storeCategory: serviceCategory,
      storeAddress: pickupAddress,
      storeDistanceKm: distanceKm * 0.3,
      customerName: isCourier ? 'Courier Delivery' : 'Customer ($serviceCategory)',
      customerPhone: '+251 91 123 4567',
      customerAddress: dropoffAddress.isNotEmpty ? dropoffAddress : dropoffName,
      customerDistanceKm: distanceKm,
      payoutAmount: fareAmount,
      tipAmount: 0.0,
      currency: currency,
      paymentMethod: paymentMethod,
      items: const [],
      totalItemCount: 1,
      deliveryNotes: isCourier ? 'Courier Package Delivery' : null,
      status: DeliveryStatus.assigned,
      createdAt: DateTime.now(),
      customerId: customerId,
      ownerId: ownerId,
      propertyName: propertyName ?? pickupName,
      storeLatitude: pickupLatitude,
      storeLongitude: pickupLongitude,
      customerLatitude: dropoffLatitude,
      customerLongitude: dropoffLongitude,
    );
  }

  bool get isCourier => orderType == 'courier' || orderType == 'courirer';
  bool get isCorporate => orderType == 'corporate' || orderType == 'company';
  bool get isPickup => orderType == 'pickup';
  bool get isStandardDelivery => !isCourier && !isCorporate && !isPickup;

  /// Elapsed seconds since notification arrived or offer was dispatched
  int get elapsedSeconds {
    final diff = DateTime.now().difference(receivedAt).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  /// Remaining seconds out of the 2-minute (120s) acceptance window
  int get remainingSeconds {
    final rem = totalDurationSeconds - elapsedSeconds;
    return rem < 0 ? 0 : rem;
  }

  /// Whether the 2-minute acceptance countdown has expired
  bool get isExpired => remainingSeconds <= 0;

  static IncomingJobOffer sample({DateTime? receivedAt}) {
    return IncomingJobOffer(
      id: 'JOB-7701',
      orderNumber: 'AMN-9102',
      pickupName: 'Prosperity Media Plc',
      pickupAddress: 'Airport Rd, Bole, Addis Ababa',
      pickupLatitude: 8.9950,
      pickupLongitude: 38.7890,
      dropoffName: 'Kality Menaharia | ቃሊቲ መናኸሪያ',
      dropoffAddress: 'Kality Ring Road Junction, Addis Ababa',
      dropoffLatitude: 8.9180,
      dropoffLongitude: 38.7610,
      surgeMultiplier: 1.5,
      customerRating: 4.5,
      serviceCategory: 'Economy',
      paymentMethod: 'Cash',
      fareAmount: 628.0,
      dropoffMinutes: 31,
      distanceKm: 13.82,
      totalDurationSeconds: 120,
      receivedAt: receivedAt,
      orderType: 'delivery',
    );
  }

  factory IncomingJobOffer.fromJson(Map<String, dynamic> data) =>
      IncomingJobOffer.fromNotificationPayload(data);

  factory IncomingJobOffer.fromNotificationPayload(Map<String, dynamic> data) {
    final rawType = (data['order_type'] ?? data['type'] ?? data['orderType'] ?? '').toString().toLowerCase();
    final rawTitle = (data['title'] ?? '').toString().toLowerCase();
    String resolvedOrderType = 'delivery';
    if (rawType.contains('courier') ||
        rawType.contains('courir') ||
        rawTitle.contains('courir') ||
        rawTitle.contains('courier') ||
        (data.containsKey('from_latitude') && (data.containsKey('reciver_name') || data.containsKey('receiver_name')))) {
      resolvedOrderType = 'courier';
    } else if (rawType.contains('corporate') ||
        rawType.contains('company') ||
        rawTitle.contains('corporate') ||
        rawTitle.contains('company')) {
      resolvedOrderType = 'corporate';
    } else if (rawType.contains('pickup') || rawTitle.contains('pickup')) {
      resolvedOrderType = 'pickup';
    }

    final orderId = data['order_id']?.toString() ??
        data['id']?.toString() ??
        '${DateTime.now().millisecondsSinceEpoch % 10000}';
    final orderNum = data['order_number']?.toString() ?? 'AMN-$orderId';

    final pickup = data['from']?.toString() ??
        data['pickup_name']?.toString() ??
        data['property_name']?.toString() ??
        data['store_name']?.toString() ??
        (resolvedOrderType == 'courier' ? 'Courier Pickup' : 'Bole Fresh Grocery');
    final pickupAddress = data['from_address']?.toString() ??
        data['pickup_address']?.toString() ??
        data['from']?.toString() ??
        data['property_address']?.toString() ??
        'Bole, Addis Ababa';
    final pLat = double.tryParse(
            data['pickup_latitude']?.toString() ??
            data['property_latitude']?.toString() ??
            data['from_latitude']?.toString() ??
            '') ??
        8.996878;
    final pLng = double.tryParse(
            data['pickup_longitude']?.toString() ??
            data['property_longitude']?.toString() ??
            data['property_longtude']?.toString() ??
            data['from_longitude']?.toString() ??
            data['from_longtude']?.toString() ??
            '') ??
        38.772777;

    final dropoff = (resolvedOrderType == 'courier'
            ? (data['receiver_name']?.toString() ??
                data['reciver_name']?.toString() ??
                data['dropoff_name']?.toString() ??
                data['to']?.toString())
            : (data['dropoff_name']?.toString() ??
                data['customer_name']?.toString() ??
                data['receiver_name']?.toString() ??
                data['reciver_name']?.toString() ??
                data['to']?.toString())) ??
        data['location']?.toString() ??
        (resolvedOrderType == 'courier' ? 'Courier Dropoff' : 'Bole Atlas, Addis Ababa');
    final dropoffAddress = data['to_address']?.toString() ??
        data['dropoff_address']?.toString() ??
        data['to']?.toString() ??
        data['location']?.toString() ??
        'Bole Atlas, Addis Ababa';
    final dLat = double.tryParse(
            data['dropoff_latitude']?.toString() ??
            data['customer_latitude']?.toString() ??
            data['to_latitude']?.toString() ??
            '') ??
        9.0054;
    final dLng = double.tryParse(
            data['dropoff_longitude']?.toString() ??
            data['customer_longitude']?.toString() ??
            data['to_longitude']?.toString() ??
            data['to_longtude']?.toString() ??
            '') ??
        38.7636;

    final rawFare = data['payment']?.toString() ??
        data['fare_amount']?.toString() ??
        data['total_km_price']?.toString() ??
        data['payment_amount']?.toString() ??
        data['total_price']?.toString() ??
        data['amount']?.toString() ??
        '';
    final cleanFare = rawFare.replaceAll(RegExp(r'[^0-9.]'), '');
    final fare = double.tryParse(cleanFare) ?? 65.0;

    String payMethod = 'Cash';
    final rawPay = data['payment_type']?.toString().toLowerCase() ??
        data['payment_method']?.toString().toLowerCase();
    if (rawPay == '1' || rawPay == 'chapa') {
      payMethod = 'Chapa';
    } else if (rawPay == '2' || rawPay == 'wallet') {
      payMethod = 'Wallet';
    }

    final cat = data['service_category']?.toString() ??
        data['category']?.toString() ??
        (resolvedOrderType == 'courier'
            ? 'Courier'
            : (resolvedOrderType == 'corporate' ? 'Corporate' : 'Economy'));
    final surge = double.tryParse(data['surge_multiplier']?.toString() ?? '') ?? 1.2;
    final rating = double.tryParse(data['customer_rating']?.toString() ?? '') ?? 4.8;
    final dropMins = int.tryParse(data['dropoff_minutes']?.toString() ?? '') ?? 25;
    final distKm = double.tryParse(data['distance_km']?.toString() ?? '') ?? 4.5;
    final durSecs = int.tryParse(
            data['duration_seconds']?.toString() ??
            data['total_duration_seconds']?.toString() ??
            '') ??
        120; // 2 minutes acceptance countdown default

    DateTime receivedTime = DateTime.now();
    if (data['received_at'] != null) {
      final ms = int.tryParse(data['received_at'].toString());
      if (ms != null) {
        receivedTime = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } else if (data['timestamp'] != null) {
      final ms = int.tryParse(data['timestamp'].toString());
      if (ms != null) {
        receivedTime = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } else if (data['created_at'] != null) {
      final parsed = DateTime.tryParse(data['created_at'].toString());
      if (parsed != null) {
        receivedTime = parsed;
      }
    }

    final custId = data['customer_id'] ??
        data['customerId'] ??
        data['user_id'] ??
        data['userId'] ??
        data['sender_user_id'] ??
        data['client_id'];
    final ownId = data['owner_id'] ??
        data['ownerId'] ??
        data['store_owner_id'] ??
        data['vendor_id'] ??
        data['merchant_id'] ??
        data['property_owner_id'];
    final propName = data['property']?.toString() ?? data['property_name']?.toString() ?? pickup;
    final rawStatus = data['status']?.toString() ?? '0';
    final statusName = rawStatus == '0' ? 'Order Placed' : (data['status_name']?.toString() ?? 'Order Placed');
    final rawCurrency = data['currency']?.toString() ??
        data['currency_code']?.toString() ??
        data['currency_symbol']?.toString() ??
        data['currency_id']?.toString();

    return IncomingJobOffer(
      id: orderId,
      orderNumber: orderNum,
      pickupName: pickup,
      pickupAddress: pickupAddress,
      pickupLatitude: pLat,
      pickupLongitude: pLng,
      dropoffName: dropoff,
      dropoffAddress: dropoffAddress,
      dropoffLatitude: dLat,
      dropoffLongitude: dLng,
      surgeMultiplier: surge,
      customerRating: rating,
      serviceCategory: cat,
      paymentMethod: payMethod,
      fareAmount: fare,
      currency: rawCurrency,
      dropoffMinutes: dropMins,
      distanceKm: distKm,
      totalDurationSeconds: durSecs,
      receivedAt: receivedTime,
      customerId: custId,
      ownerId: ownId,
      propertyName: propName,
      status: rawStatus,
      statusLabel: statusName,
      orderType: resolvedOrderType,
    );
  }
}
