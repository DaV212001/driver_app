import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/gebeta_location_service.dart';

class MapLocationResult {
  final double latitude;
  final double longitude;
  final String address;

  const MapLocationResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class MapLocationPicker extends StatefulWidget {
  final String title;
  final LatLng initialLocation;

  const MapLocationPicker({
    super.key,
    this.title = 'Select Location on Map',
    required this.initialLocation,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  GebetaMapController? _mapController;
  late LatLng _currentCenter;
  String _currentAddress = 'Locating address...';
  bool _isGeocoding = false;

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
    _currentCenter = widget.initialLocation;
    _reverseGeocodeCenter();
  }

  Future<void> _reverseGeocodeCenter() async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    try {
      final addr = await GebetaLocationService.reverseGeocode(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );
      if (mounted) {
        setState(() {
          _currentAddress = addr;
          _isGeocoding = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentAddress =
              '${_currentCenter.latitude.toStringAsFixed(4)}, ${_currentCenter.longitude.toStringAsFixed(4)} (Addis Ababa)';
          _isGeocoding = false;
        });
      }
    }
  }

  void _onCameraIdle() {
    if (_mapController != null && _canUseNativeMap) {
      final target = _mapController!.cameraPosition?.target;
      if (target != null) {
        _currentCenter = target;
        _reverseGeocodeCenter();
      }
    }
  }

  void _confirmSelection() {
    Navigator.of(context).pop(
      MapLocationResult(
        latitude: _currentCenter.latitude,
        longitude: _currentCenter.longitude,
        address: _currentAddress,
      ),
    );
  }

  Future<void> _centerOnCurrentGps() async {
    try {
      final pos = await GebetaLocationService.getCurrentPosition();
      if (pos != null && mounted) {
        final loc = LatLng(pos.latitude, pos.longitude);
        _currentCenter = loc;
        if (_mapController != null && _canUseNativeMap) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: loc, zoom: 16.5),
            ),
          );
        }
        _reverseGeocodeCenter();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. Map View
          Positioned.fill(
            child: _canUseNativeMap
                ? GebetaMap(
                    styleString: GebetaLocationService.gebetaStandardStyle,
                    initialCameraPosition: CameraPosition(
                      target: widget.initialLocation,
                      zoom: 16.0,
                    ),
                    onMapCreated: (ctrl) => _mapController = ctrl,
                    onCameraIdle: _onCameraIdle,
                    myLocationEnabled: true,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                  )
                : GestureDetector(
                    onTapDown: (details) {
                      // Allow selecting location in tests / non-mobile by tapping
                      _currentCenter = LatLng(
                        widget.initialLocation.latitude + (details.localPosition.dy - 200) * 0.0001,
                        widget.initialLocation.longitude + (details.localPosition.dx - 200) * 0.0001,
                      );
                      _reverseGeocodeCenter();
                    },
                    child: Container(
                      color: const Color(0xFF0F172A),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map_rounded, size: 64, color: Colors.white24),
                            const SizedBox(height: 12),
                            Text(
                              'Interactive Map View',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap anywhere to position map marker',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),

          // 2. Fixed Center Pin Indicator
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Move map to select location',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.location_on_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                  Container(
                    width: 8,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Current GPS Button (Top Right)
          Positioned(
            right: 16,
            top: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardBg,
                border: Border.all(color: borderCol, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location_rounded, color: AppColors.primary),
                tooltip: 'My Location',
                onPressed: _centerOnCurrentGps,
              ),
            ),
          ),

          // 4. Bottom Selection Card & Confirmation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderCol, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_rounded, color: AppColors.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isGeocoding ? 'Resolving address...' : _currentAddress,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_currentCenter.latitude.toStringAsFixed(5)}, ${_currentCenter.longitude.toStringAsFixed(5)}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isGeocoding)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirm Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
