import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../utils/currency_utils.dart';

enum DeliveryStatus {
  placed,
  assigned,
  headingToStore,
  atStore,
  pickedUp,
  delivered,
  cancelled;

  // Backward compatibility getter
  static DeliveryStatus get offered => DeliveryStatus.placed;
}

class DeliveryItemCheck {
  final String name;
  final int quantity;
  final double? unitPrice;
  final String? currency;
  bool isChecked;

  DeliveryItemCheck({
    required this.name,
    required this.quantity,
    this.unitPrice,
    this.currency,
    this.isChecked = false,
  });

  String get displayCurrency => CurrencyUtils.resolveCode(currency);
  double get totalPrice => (unitPrice ?? 0.0) * quantity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'currency': currency,
        'isChecked': isChecked,
      };

  factory DeliveryItemCheck.fromJson(Map<String, dynamic> json) =>
      DeliveryItemCheck(
        name: json['name'] as String,
        quantity: json['quantity'] as int? ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble(),
        currency: json['currency']?.toString() ??
            json['currency_code']?.toString() ??
            json['currency_symbol']?.toString() ??
            json['currency_id']?.toString(),
        isChecked: json['isChecked'] as bool? ?? false,
      );
}

class DeliveryTask {
  final String id;
  final String orderNumber;
  final String storeName;
  final String storeCategory;
  final String storeAddress;
  final double storeDistanceKm;
  final String? storePhone;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double customerDistanceKm;
  final String? deliveryNotes;
  final double payoutAmount; // Delivery Fee
  final double tipAmount; // Customer tip
  final String? currency;
  final String paymentMethod; // e.g. 'Telebirr', 'CBE Birr', 'Cash on Delivery'
  final List<DeliveryItemCheck> items;
  DeliveryStatus status;
  final DateTime createdAt;
  DateTime? completedAt;
  final String orderType; // 'delivery', 'corporate', 'pickup'
  dynamic customerId;
  dynamic ownerId;
  String? propertyName;
  String? lastReportedNotificationStatus;
  double? storeLatitude;
  double? storeLongitude;
  double? customerLatitude;
  double? customerLongitude;
  final int? totalItemCount;

  DeliveryTask({
    required this.id,
    required this.orderNumber,
    required this.storeName,
    required this.storeCategory,
    required this.storeAddress,
    required this.storeDistanceKm,
    this.storePhone = '+251 91 122 3344',
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.customerDistanceKm,
    this.deliveryNotes,
    required this.payoutAmount,
    this.tipAmount = 0.0,
    this.currency,
    this.paymentMethod = 'Telebirr',
    required this.items,
    this.status = DeliveryStatus.assigned,
    required this.createdAt,
    this.completedAt,
    this.orderType = 'delivery',
    this.customerId,
    this.ownerId,
    this.propertyName,
    this.lastReportedNotificationStatus,
    this.storeLatitude,
    this.storeLongitude,
    this.customerLatitude,
    this.customerLongitude,
    this.totalItemCount,
  });

  String get displayCurrency => CurrencyUtils.resolveCode(currency);
  String formatPayout() => CurrencyUtils.format(totalPayout, currency: currency);

  double get totalPayout => payoutAmount + tipAmount;
  int get itemCount => items.isNotEmpty
      ? items.fold(0, (sum, item) => sum + item.quantity)
      : (totalItemCount ?? 0);
  double get orderItemsSubtotal =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);
  bool get allItemsChecked => items.isEmpty || items.every((item) => item.isChecked);

  bool get isActive =>
      status == DeliveryStatus.assigned ||
      status == DeliveryStatus.headingToStore ||
      status == DeliveryStatus.atStore ||
      status == DeliveryStatus.pickedUp;

  bool get isCorporate =>
      orderType.toLowerCase() == 'corporate' ||
      orderType.toLowerCase() == 'company';
  bool get isPickup => orderType.toLowerCase() == 'pickup';
  bool get isCourier =>
      orderType.toLowerCase() == 'courier' ||
      orderType.toLowerCase() == 'courirer';
  bool get isStandardDelivery => !isCorporate && !isPickup && !isCourier;

  String get orderTypeLabel {
    if (isCourier) return 'Courier';
    if (isCorporate) return 'Corporate';
    if (isPickup) return 'Pickup';
    return 'Standard';
  }

  String get statusLabel {
    switch (status) {
      case DeliveryStatus.placed:
        return 'Order Placed';
      case DeliveryStatus.assigned:
        return 'Accepted';
      case DeliveryStatus.headingToStore:
        return 'Driver on the way to shop';
      case DeliveryStatus.atStore:
        return 'Driver on the way to shop';
      case DeliveryStatus.pickedUp:
        return 'Driver on the way to you';
      case DeliveryStatus.delivered:
        return 'Deliverd';
      case DeliveryStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get statusCode {
    switch (status) {
      case DeliveryStatus.placed:
        return '0';
      case DeliveryStatus.assigned:
        return '1';
      case DeliveryStatus.headingToStore:
      case DeliveryStatus.atStore:
        return '2';
      case DeliveryStatus.pickedUp:
        return '3';
      case DeliveryStatus.delivered:
        return '4';
      case DeliveryStatus.cancelled:
        return '5';
    }
  }

  Color get statusColor {
    switch (status) {
      case DeliveryStatus.placed:
        return const Color(0xFF4F46E5); // Indigo
      case DeliveryStatus.assigned:
        return AppColors.primary;
      case DeliveryStatus.headingToStore:
        return const Color(0xFF0284C7); // Sky blue
      case DeliveryStatus.atStore:
        return AppColors.warningAmber;
      case DeliveryStatus.pickedUp:
        return AppColors.onlineGreen;
      case DeliveryStatus.delivered:
        return AppColors.onlineGreen;
      case DeliveryStatus.cancelled:
        return AppColors.error;
    }
  }

  Color get statusBgColor {
    switch (status) {
      case DeliveryStatus.placed:
        return const Color(0xFFEEF2FF); // Soft indigo
      case DeliveryStatus.assigned:
        return AppColors.primaryContainer.withValues(alpha: 0.15);
      case DeliveryStatus.headingToStore:
        return const Color(0xFFE0F2FE);
      case DeliveryStatus.atStore:
        return AppColors.warningAmberBg;
      case DeliveryStatus.pickedUp:
        return AppColors.onlineGreenBg;
      case DeliveryStatus.delivered:
        return AppColors.onlineGreenBg;
      case DeliveryStatus.cancelled:
        return AppColors.errorContainer.withValues(alpha: 0.4);
    }
  }

  factory DeliveryTask.fromApiOrderJson(
    Map<String, dynamic> json, {
    String orderType = 'delivery',
  }) {
    final rawStatus = json['status']?.toString().trim().toLowerCase() ?? '0';
    DeliveryStatus mappedStatus;
    switch (rawStatus) {
      case '0':
      case 'placed':
      case 'order_placed':
      case 'pending':
        mappedStatus = DeliveryStatus.placed;
        break;
      case '1':
      case 'accepted':
      case 'assigned':
        mappedStatus = DeliveryStatus.assigned;
        break;
      case '2':
      case 'driver on the way to shop':
      case 'driver_to_shop':
      case 'heading_to_store':
      case 'headingtostore':
      case 'at_store':
        mappedStatus = DeliveryStatus.headingToStore;
        break;
      case '3':
      case 'driver on the way to you':
      case 'driver_to_you':
      case 'picked_up':
      case 'in_transit':
      case 'on_the_way':
      case 'out_for_delivery':
      case 'heading_to_customer':
        mappedStatus = DeliveryStatus.pickedUp;
        break;
      case '4':
      case 'deliverd':
      case 'delivered':
      case 'completed':
        mappedStatus = DeliveryStatus.delivered;
        break;
      case '5':
      case '-1':
      case 'cancelled':
      case 'canceled':
        mappedStatus = DeliveryStatus.cancelled;
        break;
      default:
        mappedStatus = DeliveryStatus.assigned;
    }

    final rawType = (json['order_type'] ?? json['type'] ?? json['orderType'] ?? '').toString().toLowerCase();
    String resolvedOrderType = orderType;
    if (rawType.contains('courier') || rawType.contains('courir')) {
      resolvedOrderType = 'courier';
    } else if (rawType.contains('corporate') || rawType.contains('company')) {
      resolvedOrderType = 'corporate';
    } else if (rawType.contains('pickup')) {
      resolvedOrderType = 'pickup';
    } else if (json.containsKey('reciver_name') || json.containsKey('receiver_name') || json.containsKey('sender_user_id')) {
      resolvedOrderType = 'courier';
    } else if (json.containsKey('company_id') || json.containsKey('branch_id')) {
      resolvedOrderType = 'corporate';
    }

    final rawId = json['id']?.toString() ?? json['order_id']?.toString() ?? '0';
    final cleanId = rawId.replaceAll(RegExp(r'[^0-9]'), '');
    final id = cleanId.isNotEmpty ? cleanId : rawId;
    final orderNum = json['order_number']?.toString() ??
        (id.startsWith('AMN-') ? id : 'AMN-$id');

    final friendlyDest = json['destination_friendly_location']?.toString() ??
        json['to_friendly_location']?.toString() ??
        json['to_address']?.toString();
    final location = (friendlyDest != null && friendlyDest.trim().isNotEmpty)
        ? friendlyDest.trim()
        : (json['location']?.toString() ?? json['to']?.toString() ?? 'Addis Ababa, Ethiopia');

    final totalPrice = double.tryParse(json['payment_amount']?.toString() ??
            json['total_price']?.toString() ??
            '150.0') ??
        150.0;
    final totalItems =
        int.tryParse(json['total_item']?.toString() ?? '1') ?? 1;

    final kmTotal = double.tryParse(json['total_km_price']?.toString() ??
        json['delivery_fee']?.toString() ??
        json['payout_amount']?.toString() ??
        '');
    final payoutAmount = kmTotal ??
        (json['driver_fee'] != null
            ? (double.tryParse(json['driver_fee'].toString()) ?? 85.0)
            : (totalPrice > 0 ? (totalPrice * 0.15).clamp(50.0, 300.0) : 85.00));

    final tipAmount = double.tryParse(
            json['tip']?.toString() ?? json['tip_amount']?.toString() ?? '0.0') ??
        0.0;

    DateTime parsedDate = DateTime.now();
    if (json['date'] != null) {
      try {
        parsedDate = DateTime.parse(json['date']);
      } catch (_) {
        if (json['created_at'] != null) {
          try {
            parsedDate = DateTime.parse(json['created_at']);
          } catch (_) {}
        }
      }
    } else if (json['created_at'] != null) {
      try {
        parsedDate = DateTime.parse(json['created_at']);
      } catch (_) {}
    }

    DateTime? completedDate;
    if (mappedStatus == DeliveryStatus.delivered) {
      if (json['updated_at'] != null) {
        try {
          completedDate = DateTime.parse(json['updated_at']);
        } catch (_) {}
      }
      completedDate ??= parsedDate;
    }

    String storeName = json['property_name']?.toString() ??
        json['property']?.toString() ??
        json['store_name']?.toString() ??
        '';
    if (storeName.trim().isEmpty ||
        storeName.toLowerCase() == 'null' ||
        storeName.toLowerCase() == 'store') {
      if (json['from_branch'] != null && json['from_branch'].toString().trim().isNotEmpty) {
        storeName = json['from_branch'].toString().trim();
      } else if (json['branch_name'] != null && json['branch_name'].toString().trim().isNotEmpty) {
        storeName = json['branch_name'].toString().trim();
      } else if (json['company_name'] != null && json['company_name'].toString().trim().isNotEmpty) {
        storeName = json['company_name'].toString().trim();
      } else if (json['restaurant_name'] != null && json['restaurant_name'].toString().trim().isNotEmpty) {
        storeName = json['restaurant_name'].toString().trim();
      } else if (resolvedOrderType == 'courier') {
        final senderName = '${json['sender_f_name'] ?? ''} ${json['sender_l_name'] ?? ''}'.trim();
        if (senderName.isNotEmpty) {
          storeName = '$senderName (Sender)';
        } else if (json['from_friendly_location'] != null && json['from_friendly_location'].toString().trim().isNotEmpty) {
          storeName = json['from_friendly_location'].toString().trim();
        } else {
          storeName = 'Courier Pickup';
        }
      } else {
        storeName = 'AMN Partner Merchant';
      }
    }

    final rawCurrency = json['currency']?.toString() ??
        json['currency_code']?.toString() ??
        json['currency_symbol']?.toString() ??
        json['currency_id']?.toString();

    List<DeliveryItemCheck> parsedItems = [];
    if (json['items'] is List) {
      for (final item in json['items']) {
        if (item is Map<String, dynamic>) {
          final itemMap = Map<String, dynamic>.from(item);
          if (itemMap['currency'] == null && rawCurrency != null) {
            itemMap['currency'] = rawCurrency;
          }
          parsedItems.add(DeliveryItemCheck.fromJson(itemMap));
        }
      }
    } else if (json['data'] is List) {
      for (final item in json['data']) {
        if (item is Map<String, dynamic> &&
            (item.containsKey('item_name') || item.containsKey('menu_name') || item.containsKey('product_name'))) {
          parsedItems.add(DeliveryItemCheck(
            name: (item['item_name'] ?? item['menu_name'] ?? item['product_name'] ?? item['name'] ?? 'Item').toString(),
            quantity: int.tryParse(item['quantity']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1,
            unitPrice: double.tryParse(item['item_price']?.toString() ?? item['price']?.toString() ?? ''),
            currency: item['currency']?.toString() ??
                item['currency_code']?.toString() ??
                rawCurrency,
            isChecked: mappedStatus == DeliveryStatus.pickedUp ||
                mappedStatus == DeliveryStatus.delivered,
          ));
        }
      }
    }

    if (parsedItems.isEmpty && json['item_name'] != null && json['item_name'].toString().trim().isNotEmpty) {
      parsedItems.add(DeliveryItemCheck(
        name: json['item_name'].toString(),
        quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
        unitPrice: double.tryParse(json['item_price']?.toString() ?? json['price']?.toString() ?? ''),
        currency: rawCurrency,
        isChecked: mappedStatus == DeliveryStatus.pickedUp ||
            mappedStatus == DeliveryStatus.delivered,
      ));
    }

    final customerId = json['customer_id'] ??
        json['customerId'] ??
        json['customer']?['id'] ??
        json['user_id'] ??
        json['userId'] ??
        json['sender_user_id'] ??
        json['client_id'];
    final ownerId = json['owner_id'] ??
        json['ownerId'] ??
        json['store_owner_id'] ??
        json['vendor_id'] ??
        json['merchant_id'] ??
        json['property_owner_id'] ??
        json['store']?['owner_id'] ??
        json['property']?['owner_id'];
    final propName = json['property']?.toString() ?? json['property_name']?.toString() ?? storeName;

    final storeLat = double.tryParse(
        json['property_latitude']?.toString() ??
        json['store_latitude']?.toString() ??
        json['restaurant_latitude']?.toString() ??
        json['from_latitude']?.toString() ??
        json['pickup_latitude']?.toString() ??
        '');
    final storeLng = double.tryParse(
        json['property_longitude']?.toString() ??
        json['property_longtude']?.toString() ??
        json['store_longitude']?.toString() ??
        json['restaurant_longitude']?.toString() ??
        json['from_longitude']?.toString() ??
        json['from_longtude']?.toString() ??
        json['pickup_longitude']?.toString() ??
        '');
    final custLat = double.tryParse(
        json['customer_latitude']?.toString() ??
        json['latitude']?.toString() ??
        json['to_latitude']?.toString() ??
        json['dropoff_latitude']?.toString() ??
        '');
    final custLng = double.tryParse(
        json['customer_longitude']?.toString() ??
        json['longitude']?.toString() ??
        json['to_longitude']?.toString() ??
        json['to_longtude']?.toString() ??
        json['dropoff_longitude']?.toString() ??
        '');

    final receiverFullName = '${json['receiver_f_name'] ?? json['reciver_f_name'] ?? ''} ${json['receiver_l_name'] ?? json['reciver_l_name'] ?? ''}'.trim();
    final customerName = json['customer_name']?.toString() ??
        json['customer']?['name']?.toString() ??
        json['receiver_name']?.toString() ??
        json['reciver_name']?.toString() ??
        (receiverFullName.isNotEmpty ? receiverFullName : null) ??
        'Customer #$id';

    final customerPhone = json['customer_phone']?.toString() ??
        json['customer']?['phone']?.toString() ??
        json['receiver_phone']?.toString() ??
        json['reciver_phone']?.toString() ??
        json['to_phone']?.toString() ??
        '+251 91 100 0000';

    final storeAddress = json['store_address']?.toString() ??
        json['restaurant_address']?.toString() ??
        json['from_friendly_location']?.toString() ??
        json['from_address']?.toString() ??
        json['from_branch']?.toString() ??
        'Bole Road, Addis Ababa';

    final storePhone = json['store_phone']?.toString() ??
        json['restaurant_phone']?.toString() ??
        json['sender_phone']?.toString() ??
        json['from_phone']?.toString() ??
        json['sender_phone_number']?.toString() ??
        '+251 91 122 3344';

    return DeliveryTask(
      id: id,
      orderNumber: orderNum,
      storeName: storeName,
      storeCategory: json['category']?.toString() ?? (resolvedOrderType == 'courier' ? 'Courier' : (resolvedOrderType == 'corporate' ? 'Corporate' : 'Food & Grocery')),
      storeAddress: storeAddress,
      storeDistanceKm:
          double.tryParse(json['store_distance']?.toString() ?? '1.5') ?? 1.5,
      storePhone: storePhone,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: location,
      customerDistanceKm:
          double.tryParse(json['distance']?.toString() ?? '3.2') ?? 3.2,
      deliveryNotes: json['notes']?.toString() ??
          json['description']?.toString() ??
          json['remark']?.toString() ??
          json['instruction']?.toString() ??
          json['package_description']?.toString(),
      payoutAmount: payoutAmount,
      tipAmount: tipAmount,
      currency: rawCurrency,
      paymentMethod:
          json['payment_type']?.toString().toUpperCase() ?? 'TELEBIRR',
      items: parsedItems,
      totalItemCount: totalItems,
      status: mappedStatus,
      createdAt: parsedDate,
      completedAt: completedDate,
      orderType: resolvedOrderType,
      customerId: customerId,
      ownerId: ownerId,
      propertyName: propName,
      storeLatitude: storeLat,
      storeLongitude: storeLng,
      customerLatitude: custLat,
      customerLongitude: custLng,
    );
  }

  DeliveryTask copyWith({
    String? id,
    String? orderNumber,
    String? storeName,
    String? storeCategory,
    String? storeAddress,
    double? storeDistanceKm,
    String? storePhone,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    double? customerDistanceKm,
    String? deliveryNotes,
    double? payoutAmount,
    double? tipAmount,
    String? currency,
    String? paymentMethod,
    List<DeliveryItemCheck>? items,
    DeliveryStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? orderType,
    dynamic customerId,
    dynamic ownerId,
    String? propertyName,
    String? lastReportedNotificationStatus,
    double? storeLatitude,
    double? storeLongitude,
    double? customerLatitude,
    double? customerLongitude,
    int? totalItemCount,
  }) {
    return DeliveryTask(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      storeName: storeName ?? this.storeName,
      storeCategory: storeCategory ?? this.storeCategory,
      storeAddress: storeAddress ?? this.storeAddress,
      storeDistanceKm: storeDistanceKm ?? this.storeDistanceKm,
      storePhone: storePhone ?? this.storePhone,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      customerDistanceKm: customerDistanceKm ?? this.customerDistanceKm,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      payoutAmount: payoutAmount ?? this.payoutAmount,
      tipAmount: tipAmount ?? this.tipAmount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      orderType: orderType ?? this.orderType,
      customerId: customerId ?? this.customerId,
      ownerId: ownerId ?? this.ownerId,
      propertyName: propertyName ?? this.propertyName,
      lastReportedNotificationStatus:
          lastReportedNotificationStatus ?? this.lastReportedNotificationStatus,
      storeLatitude: storeLatitude ?? this.storeLatitude,
      storeLongitude: storeLongitude ?? this.storeLongitude,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      totalItemCount: totalItemCount ?? this.totalItemCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_number': orderNumber,
        'store_name': storeName,
        'category': storeCategory,
        'store_address': storeAddress,
        'store_distance': storeDistanceKm,
        'store_phone': storePhone,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'location': customerAddress,
        'distance': customerDistanceKm,
        'notes': deliveryNotes,
        'payout_amount': payoutAmount,
        'tip_amount': tipAmount,
        'currency': currency,
        'payment_type': paymentMethod,
        'items': items.map((i) => i.toJson()).toList(),
        'total_item': totalItemCount,
        'status': statusCode,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'order_type': orderType,
        'customer_id': customerId,
        'owner_id': ownerId,
        'property_name': propertyName,
        'store_latitude': storeLatitude,
        'store_longitude': storeLongitude,
        'customer_latitude': customerLatitude,
        'customer_longitude': customerLongitude,
        'last_reported_notification_status': lastReportedNotificationStatus,
      };

  factory DeliveryTask.fromJson(Map<String, dynamic> json) =>
      DeliveryTask.fromApiOrderJson(json,
          orderType: json['order_type']?.toString() ?? 'delivery');
}

