import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/gebeta_route.dart';
import '../../../services/driver_location_update_service.dart';
import '../../../services/gebeta_location_service.dart';
import '../../../services/notification_service.dart';

class DriverMapCanvas extends StatefulWidget {
  final bool isOnline;
  final VoidCallback? onToggleOnline;
  final VoidCallback? onCenterLocation;
  final VoidCallback? onOpenSos;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenDestinations;
  final bool showRoute;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final String? pickupAddress;
  final String? dropoffAddress;
  final void Function(GebetaRoute route)? onRouteCalculated;

  const DriverMapCanvas({
    super.key,
    required this.isOnline,
    this.onToggleOnline,
    this.onCenterLocation,
    this.onOpenSos,
    this.onOpenNotifications,
    this.onOpenDestinations,
    this.showRoute = false,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.pickupAddress,
    this.dropoffAddress,
    this.onRouteCalculated,
  });

  @override
  State<DriverMapCanvas> createState() => _DriverMapCanvasState();
}

class _DriverMapCanvasState extends State<DriverMapCanvas> {
  GebetaMapController? _mapController;
  LatLng? _currentLocation;
  Line? _routeLine;
  Circle? _driverCircle;
  Circle? _pickupCircle;
  Circle? _dropoffCircle;
  StreamSubscription<Position>? _positionStreamSubscription;
  Worker? _locationUpdateWorker;
  bool _isCameraTrackingUser = true;
  bool _isProgrammaticCameraMove = false;
  int _routeRequestId = 0;

  bool get _canUseNativeMap {
    if (Get.testMode || Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    final inTest = Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (!inTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startLocationTracking();
        }
      });
    }
  }

  Future<void> _startLocationTracking() async {
    final inTest = Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (inTest) return;

    // 1. Initial fast GPS lock
    try {
      final pos = await GebetaLocationService.getCurrentPosition();
      if (pos != null && mounted) {
        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentLocation = loc;
        });
        _applyLocationUpdate(loc, animateCamera: true);
      }
    } catch (_) {}

    // 2. Real-time sync with DriverLocationUpdateService (centralized background & heartbeat updates)
    if (Get.isRegistered<DriverLocationUpdateService>()) {
      _locationUpdateWorker?.dispose();
      _locationUpdateWorker = ever(
        DriverLocationUpdateService.to.lastLocationSentAt,
        (_) {
          final lat = DriverLocationUpdateService.to.lastLatitude.value;
          final lng = DriverLocationUpdateService.to.lastLongitude.value;
          if (lat != null && lng != null && mounted) {
            final loc = LatLng(lat, lng);
            setState(() {
              _currentLocation = loc;
            });
            _applyLocationUpdate(loc, animateCamera: false);
          }
        },
      );
    }

    // 3. Continuous real-time GPS stream
    try {
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription =
          GebetaLocationService.getPositionStream().listen(
        (Position pos) {
          if (!mounted) return;
          final loc = LatLng(pos.latitude, pos.longitude);
          setState(() {
            _currentLocation = loc;
          });
          _applyLocationUpdate(loc, animateCamera: false);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _applyLocationUpdate(LatLng loc, {required bool animateCamera}) async {
    if (_mapController == null || !_canUseNativeMap) return;

    try {
      if (animateCamera) {
        _isProgrammaticCameraMove = true;
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: loc, zoom: 16.5),
          ),
        );
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _isProgrammaticCameraMove = false;
        });
      } else if (_isCameraTrackingUser && !widget.showRoute) {
        // If native tracking mode was dropped, smooth nudge without breaking tracking state
        // Only auto-nudge camera if NOT showing an offer route, to prevent fighting route bounds camera
        _isProgrammaticCameraMove = true;
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(loc),
        ).then((_) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _isProgrammaticCameraMove = false;
          });
        }).catchError((_) {
          _isProgrammaticCameraMove = false;
        });
      }

      await _updateDriverMarker();
    } catch (_) {
      _isProgrammaticCameraMove = false;
    }
  }

  @override
  void didUpdateWidget(covariant DriverMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline != oldWidget.isOnline) {
      _startLocationTracking();
    }
    final routeChanged = widget.showRoute != oldWidget.showRoute ||
        widget.pickupLatitude != oldWidget.pickupLatitude ||
        widget.pickupLongitude != oldWidget.pickupLongitude ||
        widget.dropoffLatitude != oldWidget.dropoffLatitude ||
        widget.dropoffLongitude != oldWidget.dropoffLongitude ||
        widget.pickupAddress != oldWidget.pickupAddress ||
        widget.dropoffAddress != oldWidget.dropoffAddress;

    if (oldWidget.showRoute && !widget.showRoute) {
      _clearRoute(recenter: true);
    } else if (routeChanged) {
      if (widget.showRoute) {
        _triggerRouteLoad();
      } else {
        _clearRoute(recenter: true);
      }
    }
  }

  void _onMapCreated(GebetaMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() async {
    final inTest = NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST');
    if (_canUseNativeMap && _mapController != null) {
      if (!inTest) {
        final hasPerm = await GebetaLocationService.ensureLocationPermission();
        if (hasPerm && _mapController != null) {
          try {
            await _mapController!.updateMyLocationTrackingMode(MyLocationTrackingMode.tracking);
          } catch (_) {}
        }
      }
      if (_currentLocation != null) {
        _applyLocationUpdate(_currentLocation!, animateCamera: false);
      } else {
        _centerOnCurrentLocation();
      }
      if (widget.showRoute) {
        _triggerRouteLoad();
      } else {
        _clearRoute(recenter: false);
      }
    }
  }

  Future<void> _updateDriverMarker() async {
    if (_mapController == null || !_canUseNativeMap) return;
    final loc = _currentLocation ?? GebetaLocationService.addisAbabaCenter;
    try {
      if (_driverCircle != null) {
        await _mapController!.updateCircle(
          _driverCircle!,
          CircleOptions(geometry: loc),
        );
      } else {
        _driverCircle = await _mapController!.addCircle(
          CircleOptions(
            geometry: loc,
            circleColor: '#009EE0',
            circleRadius: 10.0,
            circleStrokeWidth: 3.5,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      }
    } catch (_) {}
  }

  void _triggerRouteLoad() {
    final requestId = ++_routeRequestId;
    _loadAndDrawRoute(requestId);
  }

  Future<void> _loadAndDrawRoute(int requestId) async {
    if (_mapController == null || !_canUseNativeMap) return;
    if (!widget.showRoute || !mounted || requestId != _routeRequestId) return;

    try {
      final origin = _currentLocation ??
          (widget.pickupLatitude != null && widget.pickupLongitude != null
              ? LatLng(widget.pickupLatitude!, widget.pickupLongitude!)
              : GebetaLocationService.addisAbabaCenter);
      final dest = (widget.dropoffLatitude != null && widget.dropoffLongitude != null
          ? LatLng(widget.dropoffLatitude!, widget.dropoffLongitude!)
          : const LatLng(9.0054, 38.7636));

      final route = await GebetaLocationService.getRoute(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: dest.latitude,
        destLng: dest.longitude,
      );

      widget.onRouteCalculated?.call(route);

      // Verify request is still current, user hasn't declined the offer, and widget is mounted
      if (requestId != _routeRequestId || !widget.showRoute || !mounted) {
        return;
      }

      if (_mapController == null) return;

      // Ensure any existing route line is cleared before drawing new one
      try {
        await _mapController!.clearLines();
        _routeLine = null;
      } catch (_) {}

      if (requestId != _routeRequestId || !widget.showRoute || !mounted) return;

      _routeLine = await _mapController!.addLine(
        LineOptions(
          geometry: route.points,
          lineColor: '#009EE0',
          lineWidth: 5.0,
          lineOpacity: 0.9,
        ),
      );

      if (requestId != _routeRequestId || !widget.showRoute || !mounted) {
        await _clearRoute(recenter: true);
        return;
      }

      if (_pickupCircle != null) {
        try {
          await _mapController!.removeCircle(_pickupCircle!);
        } catch (_) {}
        _pickupCircle = null;
      }

      _pickupCircle = await _mapController!.addCircle(
        CircleOptions(
          geometry: route.points.first,
          circleColor: '#10B981',
          circleRadius: 8.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      if (requestId != _routeRequestId || !widget.showRoute || !mounted) {
        await _clearRoute(recenter: true);
        return;
      }

      if (_dropoffCircle != null) {
        try {
          await _mapController!.removeCircle(_dropoffCircle!);
        } catch (_) {}
        _dropoffCircle = null;
      }

      _dropoffCircle = await _mapController!.addCircle(
        CircleOptions(
          geometry: route.points.last,
          circleColor: '#EB1723',
          circleRadius: 8.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      if (requestId != _routeRequestId || !widget.showRoute || !mounted) {
        await _clearRoute(recenter: true);
        return;
      }

      _isProgrammaticCameraMove = true;
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          route.bounds,
          left: 48,
          right: 48,
          top: 100,
          bottom: 250,
        ),
      );
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _isProgrammaticCameraMove = false;
      });
    } catch (_) {
      _isProgrammaticCameraMove = false;
    }
  }

  Future<void> _clearRoute({bool recenter = true}) async {
    // Invalidate any in-flight route fetch immediately
    _routeRequestId++;

    if (mounted) {
      setState(() {});
    }

    if (_mapController == null || !_canUseNativeMap) return;

    // 1. Wipe all polylines on the map
    try {
      if (_routeLine != null) {
        await _mapController!.removeLine(_routeLine!);
      }
    } catch (_) {}
    try {
      await _mapController!.clearLines();
    } catch (_) {}
    _routeLine = null;

    // 2. Remove pickup circle
    try {
      if (_pickupCircle != null) {
        await _mapController!.removeCircle(_pickupCircle!);
      }
    } catch (_) {}
    _pickupCircle = null;

    // 3. Remove dropoff circle
    try {
      if (_dropoffCircle != null) {
        await _mapController!.removeCircle(_dropoffCircle!);
      }
    } catch (_) {}
    _dropoffCircle = null;

    // 4. Clean up all circles and restore driver marker
    try {
      await _mapController!.clearCircles();
    } catch (_) {}
    _driverCircle = null;
    await _updateDriverMarker();

    // 5. Restore camera tracking to driver's current position
    if (recenter && mounted) {
      await _centerOnCurrentLocation();
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    setState(() => _isCameraTrackingUser = true);
    if (_mapController != null && _canUseNativeMap) {
      try {
        await _mapController!.updateMyLocationTrackingMode(MyLocationTrackingMode.tracking);
      } catch (_) {}
    }
    final pos = await GebetaLocationService.getCurrentPosition();
    if (pos != null && mounted) {
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = target);
      if (_mapController != null && _canUseNativeMap) {
        _isProgrammaticCameraMove = true;
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: target, zoom: 16.5),
          ),
        );
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _isProgrammaticCameraMove = false;
        });
        _updateDriverMarker();
      }
    } else if (_currentLocation != null && _mapController != null && _canUseNativeMap) {
      _isProgrammaticCameraMove = true;
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 16.5),
        ),
      );
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _isProgrammaticCameraMove = false;
      });
    }
    widget.onCenterLocation?.call();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _locationUpdateWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Live Interactive Gebeta Map Canvas (or Test Mode Fallback Painter)
        Positioned.fill(
          child: _canUseNativeMap
              ? GebetaMap(
                  styleString: GebetaLocationService.gebetaStandardStyle,
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? GebetaLocationService.addisAbabaCenter,
                    zoom: 15.5,
                  ),
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _onStyleLoaded,
                  myLocationEnabled: !(NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST')),
                  myLocationTrackingMode: (NotificationService.skipPermissionRequest || Get.testMode || Platform.environment.containsKey('FLUTTER_TEST'))
                      ? MyLocationTrackingMode.none
                      : (_isCameraTrackingUser
                          ? MyLocationTrackingMode.tracking
                          : MyLocationTrackingMode.none),
                  myLocationRenderMode: MyLocationRenderMode.normal,
                  onUserLocationUpdated: (UserLocation loc) {
                    if (mounted) {
                      final target = loc.position;
                      setState(() => _currentLocation = target);
                      _updateDriverMarker();
                    }
                  },
                  onCameraTrackingDismissed: () {
                    // Do not cancel tracking mode if it was triggered by programmatic camera adjustments
                    if (_isProgrammaticCameraMove) return;
                    if (mounted && _isCameraTrackingUser) {
                      setState(() => _isCameraTrackingUser = false);
                    }
                  },
                  onCameraTrackingChanged: (mode) {
                    if (mounted) {
                      final isTracking = mode != MyLocationTrackingMode.none;
                      if (_isCameraTrackingUser != isTracking) {
                        setState(() => _isCameraTrackingUser = isTracking);
                      }
                    }
                  },
                  compassEnabled: true,
                  rotateGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  doubleClickZoomEnabled: true,
                  tiltGesturesEnabled: true,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                )
              : CustomPaint(
                  painter: _AddisAbabaMapPainter(
                    isOnline: widget.isOnline,
                    showRoute: widget.showRoute,
                  ),
                ),
        ),

        // 2. Right-Side Map Action Buttons
        // Destinations (Street Pickup) and My Location Target
        Positioned(
          right: 16,
          bottom: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Street Pickup Floating Button
              Semantics(
                label: 'Street Pickup',
                button: true,
                child: _StreetPickupFloatingButton(
                  onPressed: widget.onOpenDestinations,
                ),
              ),
              const SizedBox(height: 12),

              // 2. My Location Target Button
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final iconColor = _isCameraTrackingUser
                      ? AppColors.primary
                      : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant);

                  return _FloatingMapButton(
                    tooltip: 'Current Location',
                    onPressed: _centerOnCurrentLocation,
                    child: Icon(
                      _isCameraTrackingUser
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      color: iconColor,
                      size: 24,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreetPickupFloatingButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _StreetPickupFloatingButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _FloatingMapButton(
      tooltip: 'Street Pickup',
      onPressed: onPressed,
      child: Image.asset(
        AppAssets.streetPickupIcon,
        width: 26,
        height: 26,
        fit: BoxFit.contain,
        color: isDark ? Colors.white : const Color(0xFF1F2937),
      ),
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;

  const _FloatingMapButton({
    this.onPressed,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? const Color(0xFF111827).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.95);
    final defaultBorder = Border.all(
      color: isDark ? AppColors.darkOutline : AppColors.outline,
      width: 1.5,
    );
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.1);

    Widget btn = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: defaultBg,
        shape: BoxShape.circle,
        border: defaultBorder,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// Custom painter for Addis Ababa dark-styled arterial roads & landmarks
class _AddisAbabaMapPainter extends CustomPainter {
  final bool isOnline;
  final bool showRoute;

  _AddisAbabaMapPainter({
    required this.isOnline,
    required this.showRoute,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Map secondary roads
    final roadPaintSecondary = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Map primary arterial highways
    final roadPaintPrimary = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.9)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    // Draw grid of Addis Ababa arterial avenues
    // Airport Road diagonal
    final pathAirportRd = Path()
      ..moveTo(size.width * 0.1, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.4,
        size.width * 0.7,
        size.height * 0.9,
      );
    canvas.drawPath(pathAirportRd, roadPaintPrimary);

    // Bole Road / Ring Road
    final pathRingRd = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.45,
        size.width * 0.65,
        size.height * 0.65,
        size.width,
        size.height * 0.4,
      );
    canvas.drawPath(pathRingRd, roadPaintPrimary);

    // Gotera / Ethio-China link
    final pathEthioChina = Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.45, size.height);
    canvas.drawPath(pathEthioChina, roadPaintSecondary);

    // Cross connecting streets
    final pathCross1 = Path()
      ..moveTo(size.width * 0.8, 0)
      ..lineTo(size.width * 0.2, size.height * 0.8);
    canvas.drawPath(pathCross1, roadPaintSecondary);

    final pathCross2 = Path()
      ..moveTo(size.width * 0.05, size.height * 0.35)
      ..lineTo(size.width * 0.95, size.height * 0.25);
    canvas.drawPath(pathCross2, roadPaintSecondary);

    // Landmarks / Area Labels
    _drawText(canvas, 'Airport Road', Offset(size.width * 0.2, size.height * 0.32), 11);
    _drawText(canvas, 'Addis Ababa', Offset(size.width * 0.38, size.height * 0.18), 16, isBold: true);
    _drawText(canvas, 'አዲስ አበባ', Offset(size.width * 0.41, size.height * 0.21), 14);
    _drawText(canvas, 'Bole International Airport', Offset(size.width * 0.55, size.height * 0.35), 10);
    _drawText(canvas, 'Gotera', Offset(size.width * 0.25, size.height * 0.65), 11);
    _drawText(canvas, 'Kality Menaharia', Offset(size.width * 0.5, size.height * 0.75), 11);

    // Route Polyline if active (Photos 4 & 10)
    if (showRoute) {
      final routePaint = Paint()
        ..color = const Color(0xFF009EE0)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final routePath = Path()
        ..moveTo(size.width * 0.5, size.height * 0.25)
        ..lineTo(size.width * 0.45, size.height * 0.35)
        ..lineTo(size.width * 0.42, size.height * 0.48)
        ..lineTo(size.width * 0.48, size.height * 0.58)
        ..lineTo(size.width * 0.55, size.height * 0.65);

      canvas.drawPath(routePath, routePaint);

      // Pickup Marker (Green)
      final pickupPaint = Paint()..color = const Color(0xFF22C55E);
      canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.25), 10, pickupPaint);
      canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.25), 4, Paint()..color = Colors.white);

      // Dropoff Marker (Red)
      final dropoffPaint = Paint()..color = const Color(0xFFEB1723);
      canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.65), 10, dropoffPaint);
      canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.65), 4, Paint()..color = Colors.white);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, double fontSize, {bool isBold = false}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFF64748B).withValues(alpha: 0.6),
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _AddisAbabaMapPainter oldDelegate) {
    return oldDelegate.isOnline != isOnline || oldDelegate.showRoute != showRoute;
  }
}
