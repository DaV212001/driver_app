import '../config/storage_config.dart';
import '../constants/api_endpoints.dart';
import '../models/delivery_price.dart';
import '../models/delivery_task.dart';
import '../models/pickup_order_request.dart';
import 'dio_service.dart';
import 'notification_service.dart';

class DriverOrderService {
  /// Fetch assigned / active orders for the driver.
  /// Queries backend driver history endpoints across recent days (which query by driver_id and return active orders),
  /// and falls back to /my_active_order/$driverId if no active orders were found or in mocked unit test environments.
  static Future<List<DeliveryTask>> fetchActiveOrders(
    dynamic driverId, {
    String? startDate,
    String? endDate,
  }) async {
    if (driverId == null || driverId.toString().trim().isEmpty) return [];

    final activeList = <DeliveryTask>[];
    final seenIds = <String>{};

    // Calculate default date window (last 3 days to tomorrow)
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 3));
    final future = now.add(const Duration(days: 1));
    final start = startDate ??
        "${past.year.toString().padLeft(4, '0')}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}";
    final end = endDate ??
        "${future.year.toString().padLeft(4, '0')}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}";

    try {
      final results = await Future.wait([
        fetchDriverOrderHistory(startDate: start, endDate: end, driverId: driverId),
        fetchDriverCompanyOrderHistory(startDate: start, endDate: end, driverId: driverId),
        fetchDriverPickupOrderHistory(startDate: start, endDate: end, driverId: driverId),
      ]);

      for (final batch in results) {
        for (final task in batch) {
          if (task.isActive && seenIds.add('${task.orderType}_${task.id}')) {
            activeList.add(task);
          }
        }
      }
    } catch (_) {}

    if (activeList.isNotEmpty) {
      return activeList;
    }

    // Fallback: Query /my_active_order/$driverId for backward compatibility & mock adapter tests
    await DioService.dioGet(
      path: ApiEndpoints.activeOrders(driverId),
      onSuccess: (response) {
        final data = response.data;
        final rawList = data is Map<String, dynamic>
            ? (data['data'] ?? data['orders'] ?? data['active_orders'])
            : data;
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              final task = DeliveryTask.fromApiOrderJson(item);
              if (task.isActive && seenIds.add('${task.orderType}_${task.id}')) {
                activeList.add(task);
              }
            }
          }
        }
      },
      onFailure: (error, response) {},
    );

    return activeList;
  }

  /// Fetch past completed orders for the driver (GET /my_past_order/$driverId)
  static Future<List<DeliveryTask>> fetchPastOrders(dynamic driverId) async {
    final list = <DeliveryTask>[];
    await DioService.dioGet(
      path: ApiEndpoints.pastOrders(driverId),
      onSuccess: (response) {
        final data = response.data;
        final rawList = data is Map<String, dynamic>
            ? (data['data'] ?? data['orders'] ?? data['past_orders'])
            : data;
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              list.add(DeliveryTask.fromApiOrderJson(item));
            }
          }
        }
      },
      onFailure: (error, response) {},
    );
    return list;
  }

  /// Fetch standard delivery order history for date range (GET /driver-order-history/$startDate/$endDate/$driverId)
  static Future<List<DeliveryTask>> fetchDriverOrderHistory({
    required String startDate,
    required String endDate,
    dynamic driverId,
  }) async {
    final list = <DeliveryTask>[];
    await DioService.dioGet(
      path: ApiEndpoints.driverOrderHistory(startDate, endDate, driverId),
      onSuccess: (response) {
        final data = response.data;
        final rawList = data is Map<String, dynamic>
            ? (data['data'] ?? data['orders'] ?? data['order_history'] ?? data['history'])
            : data;
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              list.add(DeliveryTask.fromApiOrderJson(item, orderType: 'delivery'));
            }
          }
        }
      },
      onFailure: (error, response) {},
    );
    return list;
  }

  /// Fetch corporate / company order history for date range (GET /driver-company-order-history/$startDate/$endDate/$driverId)
  static Future<List<DeliveryTask>> fetchDriverCompanyOrderHistory({
    required String startDate,
    required String endDate,
    dynamic driverId,
  }) async {
    final list = <DeliveryTask>[];
    await DioService.dioGet(
      path: ApiEndpoints.driverCompanyOrderHistory(startDate, endDate, driverId),
      onSuccess: (response) {
        final data = response.data;
        final rawList = data is Map<String, dynamic>
            ? (data['data'] ?? data['orders'] ?? data['company_orders'] ?? data['history'])
            : data;
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              list.add(DeliveryTask.fromApiOrderJson(item, orderType: 'corporate'));
            }
          }
        }
      },
      onFailure: (error, response) {},
    );
    return list;
  }

  /// Fetch pickup order history for date range (GET /driver-pickup-order-history/$startDate/$endDate/$driverId)
  static Future<List<DeliveryTask>> fetchDriverPickupOrderHistory({
    required String startDate,
    required String endDate,
    dynamic driverId,
  }) async {
    final list = <DeliveryTask>[];
    await DioService.dioGet(
      path: ApiEndpoints.driverPickupOrderHistory(startDate, endDate, driverId),
      onSuccess: (response) {
        final data = response.data;
        final rawList = data is Map<String, dynamic>
            ? (data['data'] ?? data['orders'] ?? data['pickup_orders'] ?? data['history'])
            : data;
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              list.add(DeliveryTask.fromApiOrderJson(item, orderType: 'pickup'));
            }
          }
        }
      },
      onFailure: (error, response) {},
    );
    return list;
  }

  /// Fetch raw JSON payload for an order
  /// Supports orderType: 'courier' -> /courirer-order/$orderId, 'corporate' -> /company-order/$orderId, default -> /my_order_detail/$orderId
  static Future<Map<String, dynamic>?> fetchOrderDetailRaw(dynamic orderId, {String? orderType}) async {
    Map<String, dynamic>? dataMap;
    final resolvedType = orderType?.toLowerCase();
    final path = (resolvedType == 'courier' || resolvedType == 'courirer')
        ? ApiEndpoints.courierOrderDetail(orderId)
        : ((resolvedType == 'corporate' || resolvedType == 'company')
            ? ApiEndpoints.corporateOrderDetail(orderId)
            : ApiEndpoints.orderDetail(orderId));

    void parseResponse(dynamic resData) {
      if (resData is Map<String, dynamic>) {
        // 1. If order_status exists, it contains order header metadata (customer_id, owner_id, etc.)
        if (resData['order_status'] is Map) {
          dataMap = Map<String, dynamic>.from(resData['order_status'] as Map);
          if (resData['data'] is Map) {
            resData['data'].forEach((k, v) {
              if (!dataMap!.containsKey(k)) {
                dataMap![k] = v;
              }
            });
          }
          return;
        }

        // 2. If data is a Map, it contains order details
        if (resData['data'] is Map<String, dynamic>) {
          dataMap = Map<String, dynamic>.from(resData['data'] as Map);
          return;
        }

        // 3. If order is a Map
        if (resData['order'] is Map<String, dynamic>) {
          dataMap = Map<String, dynamic>.from(resData['order'] as Map);
          return;
        }

        // 4. If data is a List and items contain customer/owner info or fallback
        if (resData['data'] is List && (resData['data'] as List).isNotEmpty) {
          final first = (resData['data'] as List).first;
          if (first is Map) {
            dataMap = Map<String, dynamic>.from(first);
            return;
          }
        }

        // 5. Fallback to top-level
        dataMap = resData;
      }
    }

    await DioService.dioGet(
      path: path,
      onSuccess: (response) {
        parseResponse(response.data);
      },
      onFailure: (error, response) {},
    );

    // Resilient fallback if primary endpoint returned nothing or failed
    if (dataMap == null) {
      if (resolvedType == 'courier' || resolvedType == 'courirer' || resolvedType == 'corporate' || resolvedType == 'company') {
        await DioService.dioGet(
          path: ApiEndpoints.orderDetail(orderId),
          onSuccess: (response) => parseResponse(response.data),
          onFailure: (error, response) {},
        );
      } else {
        await DioService.dioGet(
          path: ApiEndpoints.courierOrderDetail(orderId),
          onSuccess: (response) => parseResponse(response.data),
          onFailure: (error, response) {},
        );
        if (dataMap == null) {
          await DioService.dioGet(
            path: ApiEndpoints.corporateOrderDetail(orderId),
            onSuccess: (response) => parseResponse(response.data),
            onFailure: (error, response) {},
          );
        }
      }
    }

    return dataMap;
  }

  /// Fetch single order details
  /// Supports orderType: 'courier' -> /courirer-order/$orderId, 'corporate' -> /company-order/$orderId, default -> /my_order_detail/$orderId
  static Future<DeliveryTask?> fetchOrderDetail(dynamic orderId, {String? orderType}) async {
    DeliveryTask? task;
    final resolvedType = orderType?.toLowerCase();
    final path = (resolvedType == 'courier' || resolvedType == 'courirer')
        ? ApiEndpoints.courierOrderDetail(orderId)
        : ((resolvedType == 'corporate' || resolvedType == 'company')
            ? ApiEndpoints.corporateOrderDetail(orderId)
            : ApiEndpoints.orderDetail(orderId));

    void parseResponse(dynamic responseData) {
      if (responseData is Map<String, dynamic>) {
        final itemsList = responseData['data'] is List ? responseData['data'] as List : [];
        final statusMap = responseData['order_status'] is Map<String, dynamic>
            ? responseData['order_status'] as Map<String, dynamic>
            : (responseData['data'] is Map<String, dynamic>
                ? responseData['data'] as Map<String, dynamic>
                : (itemsList.isNotEmpty && itemsList.first is Map
                    ? itemsList.first as Map<String, dynamic>
                    : responseData));

        final Map<String, dynamic> combined = Map<String, dynamic>.from(statusMap);
        if (itemsList.isNotEmpty && !combined.containsKey('items') && !combined.containsKey('data')) {
          combined['items'] = itemsList;
        }

        task = DeliveryTask.fromApiOrderJson(
          combined,
          orderType: orderType ?? (resolvedType == 'courier' ? 'courier' : (resolvedType == 'corporate' ? 'corporate' : 'delivery')),
        );
      }
    }

    await DioService.dioGet(
      path: path,
      onSuccess: (response) {
        parseResponse(response.data);
      },
      onFailure: (error, response) {},
    );

    // Resilient fallback if primary endpoint returned nothing or failed
    if (task == null) {
      if (resolvedType == 'courier' || resolvedType == 'courirer') {
        // Fallback to standard
        await DioService.dioGet(
          path: ApiEndpoints.orderDetail(orderId),
          onSuccess: (response) => parseResponse(response.data),
          onFailure: (error, response) {},
        );
      } else if (resolvedType == 'corporate' || resolvedType == 'company') {
        // Fallback to standard
        await DioService.dioGet(
          path: ApiEndpoints.orderDetail(orderId),
          onSuccess: (response) => parseResponse(response.data),
          onFailure: (error, response) {},
        );
      } else {
        // Fallback to courier then corporate
        await DioService.dioGet(
          path: ApiEndpoints.courierOrderDetail(orderId),
          onSuccess: (response) => parseResponse(response.data),
          onFailure: (error, response) {},
        );
        if (task == null) {
          await DioService.dioGet(
            path: ApiEndpoints.corporateOrderDetail(orderId),
            onSuccess: (response) => parseResponse(response.data),
            onFailure: (error, response) {},
          );
        }
      }
    }

    return task;
  }

  /// Accept an incoming order (POST /orders/{orderId}/accept-order)
  static Future<bool> acceptOrder({
    required dynamic orderId,
    required dynamic driverId,
    Function(Map<String, dynamic> data)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    bool success = false;
    await DioService.dioPost(
      path: ApiEndpoints.acceptOrder(orderId),
      data: {
        'driver_id': driverId,
      },
      onSuccess: (response) {
        success = true;
        // Dispatch status 1 notification
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: '1',
        );
        if (response.data is Map<String, dynamic>) {
          onSuccess?.call(response.data as Map<String, dynamic>);
        } else {
          onSuccess?.call({'message': 'Order accepted successfully'});
        }
      },
      onFailure: (error, response) {
        String msg = 'Failed to accept order';
        if (response.data is Map<String, dynamic>) {
          msg = response.data['message']?.toString() ?? msg;
        }
        onFailure?.call(msg);
      },
    );
    return success;
  }

  /// Update standard delivery order status (POST /orders/{orderId}/update-order)
  static Future<bool> updateStandardOrderStatus({
    required dynamic orderId,
    required int status,
    dynamic driverId,
    Function(Map<String, dynamic> data)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    bool success = false;
    final effectiveDriverId = driverId ?? StorageConfig.getDriverId();
    final cleanDriverId = effectiveDriverId != null
        ? int.tryParse(effectiveDriverId.toString().replaceAll(RegExp(r'[^0-9]'), ''))
        : null;
    final payload = <String, dynamic>{
      'status': status,
      'driver_id': ?cleanDriverId,
    };
    await DioService.dioPost(
      path: ApiEndpoints.updateStandardOrder(orderId),
      data: payload,
      onSuccess: (response) {
        success = true;
        // Dispatch order status notification on update
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: status.toString(),
        );
        Map<String, dynamic> resData = {'message': 'Order updated successfully'};
        if (response.data is Map<String, dynamic>) {
          resData = response.data as Map<String, dynamic>;
        } else if (response.data is Map) {
          resData = Map<String, dynamic>.from(response.data as Map);
        }
        onSuccess?.call(resData);
      },
      onFailure: (error, response) {
        String msg = 'Failed to update order status';
        if (response.data is Map<String, dynamic>) {
          msg = response.data['message']?.toString() ?? msg;
        } else if (response.data is Map) {
          msg = (response.data as Map)['message']?.toString() ?? msg;
        }
        onFailure?.call(msg);
      },
    );
    return success;
  }

  /// Create a new pickup order from driver (POST /pickup-order)
  static Future<Map<String, dynamic>?> createPickupOrder({
    required PickupOrderRequest request,
    Function(Map<String, dynamic> data)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    Map<String, dynamic>? result;
    await DioService.dioPost(
      path: ApiEndpoints.pickupOrder,
      data: request.toJson(),
      onSuccess: (response) {
        if (response.data is Map<String, dynamic>) {
          result = response.data as Map<String, dynamic>;
        } else if (response.data is Map) {
          result = Map<String, dynamic>.from(response.data as Map);
        } else {
          result = {'success': true, 'data': response.data};
        }
        onSuccess?.call(result!);
      },
      onFailure: (error, response) {
        String msg = 'Failed to create pickup order';
        if (response.data is Map<String, dynamic>) {
          msg = response.data['message']?.toString() ?? msg;
        } else if (response.data is Map) {
          msg = (response.data as Map)['message']?.toString() ?? msg;
        }
        onFailure?.call(msg);
      },
    );
    return result;
  }

  /// Fetch delivery price rates by car type ID and city ID
  /// (GET /delivery-price-by-car-and-city-id/{vehicle_id}/{city_id})
  static Future<DeliveryPriceModel?> fetchDeliveryPrice({
    required dynamic vehicleId,
    required dynamic cityId,
  }) async {
    DeliveryPriceModel? price;
    await DioService.dioGet(
      path: ApiEndpoints.deliveryPriceByCarAndCity(vehicleId, cityId),
      onSuccess: (response) {
        final data = response.data;
        final raw = data is Map ? (data['data'] ?? data) : data;
        if (raw is List && raw.isNotEmpty) {
          final first = raw.first;
          if (first is Map) {
            price = DeliveryPriceModel.fromJson(Map<String, dynamic>.from(first));
          }
        } else if (raw is Map) {
          price = DeliveryPriceModel.fromJson(Map<String, dynamic>.from(raw));
        }

        if (price != null) {
          StorageConfig.setPickupKmPrice(price!.pickupKmPrice);
          StorageConfig.setPickupStartPrice(price!.pickupStartPrice);
        }
      },
      onFailure: (error, response) {
        // Handled by caller
      },
    );
    return price;
  }

  /// Update order status for a pickup order (POST /pickup-order/{orderId}/update-order)
  static Future<bool> updatePickupOrderStatus({
    required dynamic orderId,
    required int status,
    Function(Map<String, dynamic> data)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    bool success = false;
    await DioService.dioPost(
      path: ApiEndpoints.updatePickupOrder(orderId),
      data: {
        'status': status,
      },
      onSuccess: (response) {
        success = true;
        // Dispatch order status notification on update
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: status.toString(),
        );
        Map<String, dynamic> resData = {'message': 'Order updated successfully'};
        if (response.data is Map<String, dynamic>) {
          resData = response.data as Map<String, dynamic>;
        } else if (response.data is Map) {
          resData = Map<String, dynamic>.from(response.data as Map);
        }
        onSuccess?.call(resData);
      },
      onFailure: (error, response) {
        String msg = 'Failed to update order status';
        if (response.data is Map<String, dynamic>) {
          msg = response.data['message']?.toString() ?? msg;
        } else if (response.data is Map) {
          msg = (response.data as Map)['message']?.toString() ?? msg;
        }
        onFailure?.call(msg);
      },
    );
    return success;
  }

  /// Update courier order status (POST /courirer-order/{orderId}/update-order)
  static Future<bool> updateCourierOrderStatus({
    required dynamic orderId,
    required int status,
    dynamic driverId,
    Function(Map<String, dynamic> data)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    bool success = false;
    final effectiveDriverId = driverId ?? StorageConfig.getDriverId();
    final cleanDriverId = effectiveDriverId != null
        ? int.tryParse(effectiveDriverId.toString().replaceAll(RegExp(r'[^0-9]'), ''))
        : null;
    final payload = <String, dynamic>{
      'status': status,
      'driver_id': ?cleanDriverId,
    };
    await DioService.dioPost(
      path: ApiEndpoints.updateCourierOrder(orderId),
      data: payload,
      onSuccess: (response) {
        success = true;
        // Dispatch order status notification on update
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: status.toString(),
        );
        Map<String, dynamic> resData = {'message': 'Courier order updated successfully'};
        if (response.data is Map<String, dynamic>) {
          resData = response.data as Map<String, dynamic>;
        } else if (response.data is Map) {
          resData = Map<String, dynamic>.from(response.data as Map);
        }
        onSuccess?.call(resData);
      },
      onFailure: (error, response) {
        String msg = 'Failed to update courier order status';
        if (response.data is Map<String, dynamic>) {
          msg = response.data['message']?.toString() ?? msg;
        } else if (response.data is Map) {
          msg = (response.data as Map)['message']?.toString() ?? msg;
        }
        onFailure?.call(msg);
      },
    );
    return success;
  }

  /// Update corporate order status (POST /corporate-order/{orderId}/update-order)
  static Future<bool> updateCorporateOrderStatus({
    required dynamic orderId,
    required int status,
    dynamic driverId,
    Function(Map<String, dynamic> data)? onSuccess,
    Function(String error)? onFailure,
  }) async {
    bool success = false;
    final effectiveDriverId = driverId ?? StorageConfig.getDriverId();
    final cleanDriverId = effectiveDriverId != null
        ? int.tryParse(effectiveDriverId.toString().replaceAll(RegExp(r'[^0-9]'), ''))
        : null;
    final payload = <String, dynamic>{
      'status': status,
      'driver_id': ?cleanDriverId,
    };
    await DioService.dioPost(
      path: ApiEndpoints.updateCorporateOrder(orderId),
      data: payload,
      onSuccess: (response) {
        success = true;
        // Dispatch order status notification on update
        NotificationService.instance.notifyOrderStatusChanged(
          orderId: orderId,
          status: status.toString(),
        );
        Map<String, dynamic> resData = {'message': 'Corporate order updated successfully'};
        if (response.data is Map<String, dynamic>) {
          resData = response.data as Map<String, dynamic>;
        } else if (response.data is Map) {
          resData = Map<String, dynamic>.from(response.data as Map);
        }
        onSuccess?.call(resData);
      },
      onFailure: (error, response) {
        String msg = 'Failed to update corporate order status';
        if (response.data is Map<String, dynamic>) {
          msg = response.data['message']?.toString() ?? msg;
        } else if (response.data is Map) {
          msg = (response.data as Map)['message']?.toString() ?? msg;
        }
        onFailure?.call(msg);
      },
    );
    return success;
  }
}
