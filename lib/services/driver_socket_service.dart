import 'dart:io';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../config/storage_config.dart';
import '../constants/constants.dart';
import 'notification_service.dart';

class DriverSocketService extends GetxService {
  static DriverSocketService get to => Get.find<DriverSocketService>();

  socket_io.Socket? _socket;
  socket_io.Socket? get socket => _socket;

  final RxBool isConnected = false.obs;
  final RxBool isCustomerOnline = false.obs;
  final RxString currentActiveOrderId = ''.obs;
  final RxString lastError = ''.obs;
  final Rxn<DateTime> lastLocationSentAt = Rxn<DateTime>();
  double? lastLatitude;
  double? lastLongitude;
  double? lastHeading;

  final Logger _logger = Logger();
  bool isTestMode = false;

  static bool get isInTest =>
      NotificationService.skipPermissionRequest ||
      Get.testMode ||
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void onInit() {
    super.onInit();
    // Auto-connect if driver is logged in and not running in pure test mode
    if (!isInTest && StorageConfig.isLoggedIn()) {
      connect();
    }
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }

  /// Initialize and connect Socket.IO connection to Render backend
  void connect({String? serverUrl}) {
    if (isTestMode || isInTest) {
      isConnected.value = true;
      return;
    }

    if (_socket != null && _socket!.connected) {
      return;
    }

    final rawDriverId = StorageConfig.getDriverId() ?? '1';
    final cleanDriverId = rawDriverId.replaceAll(RegExp(r'[^0-9]'), '');
    final driverId = cleanDriverId.isNotEmpty ? cleanDriverId : rawDriverId;
    final token = StorageConfig.getToken() ?? '';
    final url = serverUrl ?? kSocketServerUrl;

    try {
      _logger.i('🔌 Connecting Driver Socket to: $url (driverId: $driverId)');

      if (_socket != null) {
        try {
          _socket!.dispose();
        } catch (_) {}
        _socket = null;
      }

      _socket = socket_io.io(
        url,
        socket_io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({
              'userId': driverId,
              'role': 'driver',
              'token': token,
            })
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket!.onConnect((_) {
        isConnected.value = true;
        _logger.i('✅ Driver Socket connected to Render! [ID: ${_socket?.id}]');

        // Rejoin active order if reconnecting mid-delivery and flush latest position
        if (currentActiveOrderId.value.isNotEmpty) {
          final activeId = currentActiveOrderId.value;
          final activeType = StorageConfig.getActiveOrderType();
          _performJoinOrder(activeId, orderType: activeType, onResult: (success) {
            if (success && lastLatitude != null && lastLongitude != null) {
              sendLocation(
                orderId: activeId,
                latitude: lastLatitude!,
                longitude: lastLongitude!,
                heading: lastHeading,
              );
            }
          });
        }
      });

      _socket!.onDisconnect((reason) {
        isConnected.value = false;
        isCustomerOnline.value = false;
        _logger.w('❌ Driver Socket disconnected: $reason');
      });

      _socket!.onConnectError((err) {
        isConnected.value = false;
        _logger.e('Driver Socket connect_error: $err');
      });

      // Customer presence events
      _socket!.on('order:peer:joined', (data) {
        _logger.i('📱 Customer came online in order room: $data');
        isCustomerOnline.value = true;
      });

      _socket!.on('order:peer:left', (data) {
        _logger.i('Customer left order room: $data');
        isCustomerOnline.value = false;
      });

      // Error event from server (e.g. DRIVER_MISMATCH, ORDER_INACTIVE, INVALID_PAYLOAD)
      // Logged for developer diagnostics only; never show technical error popups to drivers.
      _socket!.on('order:error', (error) {
        final code = (error is Map ? error['code']?.toString() : null) ?? 'ERROR';
        final message = (error is Map ? error['message']?.toString() : error?.toString()) ?? 'Socket error occurred';
        lastError.value = message;
        _logger.w('⚠️ Socket Server Error [$code]: $message');
      });
    } catch (e, stack) {
      _logger.e('Failed to initialize Driver Socket', error: e, stackTrace: stack);
    }
  }

  /// Authenticate and join tracking room for an active order with automatic retry
  void joinOrder(String orderId, {String? orderType, Function(bool success)? onResult, int attempt = 0}) {
    currentActiveOrderId.value = orderId;
    if (orderType != null && orderType.isNotEmpty) {
      StorageConfig.setActiveOrderType(orderType);
    }

    if (isTestMode || isInTest) {
      isCustomerOnline.value = true;
      onResult?.call(true);
      return;
    }

    if (_socket == null || !_socket!.connected) {
      _logger.i('Driver Socket not connected yet. Connecting before joining Order #$orderId...');
      connect();

      // Wait for socket to establish connection before emitting order:join
      if (_socket != null) {
        _socket!.once('connect', (_) {
          if (currentActiveOrderId.value == orderId) {
            _performJoinOrder(orderId, orderType: orderType, onResult: onResult, attempt: attempt);
          }
        });
      }
      return;
    }

    _performJoinOrder(orderId, orderType: orderType, onResult: onResult, attempt: attempt);
  }

  void _performJoinOrder(String orderId, {String? orderType, Function(bool success)? onResult, int attempt = 0}) {
    if (isTestMode || isInTest) {
      isCustomerOnline.value = true;
      onResult?.call(true);
      return;
    }

    if (_socket == null || !_socket!.connected) {
      if (attempt < 3 && currentActiveOrderId.value == orderId) {
        Future.delayed(Duration(seconds: (attempt + 1) * 2), () {
          if (currentActiveOrderId.value == orderId) {
            joinOrder(orderId, orderType: orderType, onResult: onResult, attempt: attempt + 1);
          }
        });
      } else {
        onResult?.call(false);
      }
      return;
    }

    final rawDriverId = StorageConfig.getDriverId() ?? '1';
    final cleanDriverId = rawDriverId.replaceAll(RegExp(r'[^0-9]'), '');
    final driverId = cleanDriverId.isNotEmpty ? cleanDriverId : rawDriverId;
    final token = StorageConfig.getToken() ?? '';
    final effectiveOrderType = orderType ?? StorageConfig.getActiveOrderType();

    _logger.i('Requesting join tracking for Order #$orderId [type: $effectiveOrderType] (driverId: $driverId, attempt ${attempt + 1})...');

    _socket?.emitWithAck(
      'order:join',
      {
        'orderId': orderId,
        'userId': driverId,
        'role': 'driver',
        'token': token,
        if (effectiveOrderType != null && effectiveOrderType.isNotEmpty)
          'orderType': effectiveOrderType,
      },
      ack: (response) {
        if (response is Map && response['success'] == true) {
          final data = response['data'] as Map?;
          final peerConnected = data?['peerConnected'] == true;
          isCustomerOnline.value = peerConnected;
          _logger.i('✅ Successfully joined Order #$orderId! [peerConnected: $peerConnected]');
          onResult?.call(true);
        } else {
          final errorMsg = response is Map && response['error'] is Map
              ? response['error']['message']?.toString()
              : 'Failed to join tracking room';
          lastError.value = errorMsg ?? '';
          _logger.w('Failed to join tracking room: $errorMsg (attempt ${attempt + 1})');

          // Auto-retry up to 3 times with backoff if this order is still active
          if (attempt < 3 && currentActiveOrderId.value == orderId) {
            Future.delayed(Duration(seconds: (attempt + 1) * 2), () {
              if (currentActiveOrderId.value == orderId) {
                joinOrder(orderId, orderType: effectiveOrderType, onResult: onResult, attempt: attempt + 1);
              }
            });
          } else {
            onResult?.call(false);
          }
        }
      },
    );
  }

  /// Broadcast live GPS coordinates to customer tracking map
  void sendLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    double? heading,
    double? speed,
    double? accuracy,
  }) {
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastHeading = heading;

    if (isTestMode || isInTest) {
      lastLocationSentAt.value = DateTime.now();
      return;
    }

    if (_socket != null && _socket!.connected) {
      _socket!.emit('driver:location:update', {
        'orderId': orderId,
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading ?? 0.0,
        'speed': speed ?? 0.0,
        'accuracy': accuracy ?? 5.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      lastLocationSentAt.value = DateTime.now();
      _logger.d('📍 Sent GPS location: [$latitude, $longitude] heading: $heading°');
    }
  }

  /// Update estimated arrival time (minutes and remaining distance)
  void sendEta({
    required String orderId,
    required int estimatedMinutes,
    double? remainingDistanceMeters,
    String? polyline,
  }) {
    if (isTestMode || Get.testMode) return;

    if (_socket != null && _socket!.connected) {
      final payload = <String, dynamic>{
        'orderId': orderId,
        'estimatedMinutes': estimatedMinutes,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (remainingDistanceMeters != null && !remainingDistanceMeters.isNaN && remainingDistanceMeters >= 0) {
        payload['remainingDistanceMeters'] = remainingDistanceMeters;
      }
      if (polyline != null && polyline.isNotEmpty) {
        payload['polyline'] = polyline;
      }

      _socket!.emit('driver:eta:update', payload);
      _logger.d('⏱️ Sent ETA update: $estimatedMinutes mins');
    }
  }

  /// Broadcast order status progression (heading to store, picked up, arrived, delivered)
  void sendStatusUpdate({
    required String orderId,
    required String status,
    String? statusName,
    String? notes,
  }) {
    if (isTestMode || Get.testMode) return;

    if (_socket != null && _socket!.connected) {
      final payload = <String, dynamic>{
        'orderId': orderId,
        'status': status,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (statusName != null && statusName.isNotEmpty) {
        payload['statusName'] = statusName;
      }
      if (notes != null && notes.isNotEmpty) {
        payload['notes'] = notes;
      }

      _socket!.emit('order:status:update', payload);
      _logger.i('📦 Emitted order status update: $status');
    }
  }

  /// Send in-delivery chat message to the customer
  void sendMessage({
    required String orderId,
    required String message,
  }) {
    if (isTestMode || Get.testMode) return;

    if (_socket != null && _socket!.connected) {
      final driverId = StorageConfig.getDriverId() ?? '1';
      final driverName = StorageConfig.getDriverName() ?? 'Driver';

      _socket!.emit('order:message:send', {
        'orderId': orderId,
        'senderId': driverId,
        'senderRole': 'driver',
        'senderName': driverName,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _logger.i('💬 Sent chat message: "$message"');
    }
  }

  /// Leave order tracking room
  void leaveOrder(String orderId) {
    if (_socket != null && _socket!.connected) {
      final driverId = StorageConfig.getDriverId() ?? '1';
      _socket!.emit('order:leave', {
        'orderId': orderId,
        'userId': driverId,
      });
    }
    if (currentActiveOrderId.value == orderId) {
      currentActiveOrderId.value = '';
      isCustomerOnline.value = false;
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    isConnected.value = false;
    isCustomerOnline.value = false;
  }
}
