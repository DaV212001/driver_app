import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gebeta_gl/gebeta_gl.dart';
import 'package:get/get.dart';
import '../../../config/storage_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/country_code.dart';
import '../../../models/delivery_price.dart';
import '../../../models/gebeta_place_suggestion.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/driver_auth_service.dart';
import '../../../services/driver_location_update_service.dart';
import '../../../services/driver_order_service.dart';
import '../../../services/gebeta_location_service.dart';
import '../../../utils/location_utils.dart';
import '../../../widgets/common/country_code_dropdown.dart';
import 'map_location_picker.dart';

class StreetPickupBottomSheet extends StatefulWidget {
  final double? initialFromLatitude;
  final double? initialFromLongitude;
  final String? initialPickupAddress;
  final Function({
    required String pickupAddress,
    required String destinationAddress,
    required String serviceCategory,
    required String customerPhone,
    double? fromLatitude,
    double? fromLongitude,
    double? toLatitude,
    double? toLongitude,
    int? carTypeId,
    double? basePrice,
    double? kmPrice,
    double? totalKm,
    double? totalPrice,
    String? description,
    String? fromFriendlyLocation,
    String? toFriendlyLocation,
  }) onCreateOrder;

  const StreetPickupBottomSheet({
    super.key,
    required this.onCreateOrder,
    this.initialFromLatitude,
    this.initialFromLongitude,
    this.initialPickupAddress,
  });

  @override
  State<StreetPickupBottomSheet> createState() => _StreetPickupBottomSheetState();
}

class _StreetPickupBottomSheetState extends State<StreetPickupBottomSheet> {
  final TextEditingController _pickupCtrl = TextEditingController();
  final TextEditingController _destinationCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _kmPriceCtrl = TextEditingController(text: '0.00');
  final TextEditingController _totalPriceCtrl = TextEditingController(text: '0.00');
  static const String _defaultService = 'Economy';

  int _step = 0; // 0 = Enter destination & details, 1 = Review total km & total price
  double? _fromLatitude;
  double? _fromLongitude;
  double? _toLatitude;
  double? _toLongitude;
  bool _isLoadingDeparture = false;
  CountryCode _selectedCountry = CountryCode.defaultCountry;

  // Vehicle & delivery pricing configuration
  double _calculatedDistanceKm = 0.0;
  double _pickupKmPrice = 23.21;
  double _pickupStartPrice = 168.66;
  int _carTypeId = 1;

  // Autocomplete state for Pickup (Departure)
  List<GebetaPlaceSuggestion> _pickupSuggestions = [];
  bool _isSearchingPickup = false;
  Timer? _pickupDebounce;
  final FocusNode _pickupFocusNode = FocusNode();

  // Autocomplete state for Destination
  List<GebetaPlaceSuggestion> _destinationSuggestions = [];
  bool _isSearchingDestination = false;
  Timer? _destinationDebounce;
  final FocusNode _destinationFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initDepartureLocation();
    _initVehiclePricing();
  }

  Future<void> _initVehiclePricing() async {
    final cachedKm = StorageConfig.getPickupKmPrice();
    final cachedStart = StorageConfig.getPickupStartPrice();
    if (cachedKm != null && cachedKm > 0) _pickupKmPrice = cachedKm;
    if (cachedStart != null && cachedStart > 0) _pickupStartPrice = cachedStart;
    _recalculatePrice();

    try {
      final storedVehicleIdStr = StorageConfig.getDriverVehicleId();
      final storedCityIdStr = StorageConfig.getDriverCityId();
      final vehicleId = (storedVehicleIdStr != null && storedVehicleIdStr.isNotEmpty)
          ? (int.tryParse(storedVehicleIdStr) ?? 1)
          : 1;
      final cityId = (storedCityIdStr != null && storedCityIdStr.isNotEmpty)
          ? (int.tryParse(storedCityIdStr) ?? 1)
          : 1;
      _carTypeId = vehicleId;

      final results = await Future.wait([
        DriverAuthService.fetchVehicleTypes(),
        DriverOrderService.fetchDeliveryPrice(vehicleId: vehicleId, cityId: cityId),
      ]);

      final vehicleTypes = results[0] as List<VehicleTypeModel>;
      final deliveryPrice = results[1] as DeliveryPriceModel?;

      if (vehicleTypes.isNotEmpty) {
        final matched = vehicleTypes.firstWhereOrNull((v) => v.id == vehicleId) ?? vehicleTypes.first;
        _carTypeId = matched.id;
      }

      if (deliveryPrice != null) {
        if (deliveryPrice.pickupKmPrice > 0) {
          _pickupKmPrice = deliveryPrice.pickupKmPrice;
        }
        if (deliveryPrice.pickupStartPrice > 0) {
          _pickupStartPrice = deliveryPrice.pickupStartPrice;
        }
      }
    } catch (_) {
      // Gracefully retain cached or fallback defaults (23.21 / 168.66)
    } finally {
      if (mounted) {
        setState(() {});
        _recalculatePrice();
      }
    }
  }

  void _recalculatePrice() {
    if (_fromLatitude != null &&
        _fromLongitude != null &&
        _toLatitude != null &&
        _toLongitude != null) {
      final distance = LocationUtils.calculateDistanceInKm(
        lat1: _fromLatitude!,
        lon1: _fromLongitude!,
        lat2: _toLatitude!,
        lon2: _toLongitude!,
      );
      _calculatedDistanceKm = distance;
      final total = (_pickupKmPrice * distance) + _pickupStartPrice;

      _kmPriceCtrl.text = _pickupKmPrice.toStringAsFixed(2);
      _totalPriceCtrl.text = total.toStringAsFixed(2);
    } else {
      _calculatedDistanceKm = 0.0;
      _kmPriceCtrl.text = _pickupKmPrice.toStringAsFixed(2);
      _totalPriceCtrl.text = _pickupStartPrice > 0
          ? _pickupStartPrice.toStringAsFixed(2)
          : '0.00';
    }
  }

  Future<void> _initDepartureLocation() async {
    if (widget.initialFromLatitude != null && widget.initialFromLongitude != null) {
      _fromLatitude = widget.initialFromLatitude;
      _fromLongitude = widget.initialFromLongitude;
      if (widget.initialPickupAddress != null && widget.initialPickupAddress!.isNotEmpty) {
        _pickupCtrl.text = widget.initialPickupAddress!;
        return;
      }
    }

    setState(() => _isLoadingDeparture = true);

    try {
      double? lat;
      double? lng;

      // 1. Check DriverLocationUpdateService if registered
      if (Get.isRegistered<DriverLocationUpdateService>()) {
        lat = DriverLocationUpdateService.to.lastLatitude.value;
        lng = DriverLocationUpdateService.to.lastLongitude.value;
      }

      // 2. Query hardware / cached position
      if (lat == null || lng == null) {
        final pos = await GebetaLocationService.getCurrentPosition();
        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
        }
      }

      // 3. Fallback to center coordinates if unavailable (not hardcoded Bole)
      lat ??= GebetaLocationService.addisAbabaCenter.latitude;
      lng ??= GebetaLocationService.addisAbabaCenter.longitude;

      _fromLatitude = lat;
      _fromLongitude = lng;

      // 4. Reverse geocode driver's current position
      final geocoded = await GebetaLocationService.reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _pickupCtrl.text = geocoded;
          _isLoadingDeparture = false;
        });
        _recalculatePrice();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingDeparture = false);
      }
    }
  }

  Future<void> _pickDepartureOnMap() async {
    final initial = LatLng(
      _fromLatitude ?? GebetaLocationService.addisAbabaCenter.latitude,
      _fromLongitude ?? GebetaLocationService.addisAbabaCenter.longitude,
    );

    final result = await showModalBottomSheet<MapLocationResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MapLocationPicker(
        title: 'Set Departure Location',
        initialLocation: initial,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _fromLatitude = result.latitude;
        _fromLongitude = result.longitude;
        _pickupCtrl.text = result.address;
      });
      _recalculatePrice();
    }
  }

  Future<void> _pickDestinationOnMap() async {
    final initial = LatLng(
      _toLatitude ?? (_fromLatitude ?? GebetaLocationService.addisAbabaCenter.latitude),
      _toLongitude ?? (_fromLongitude ?? GebetaLocationService.addisAbabaCenter.longitude),
    );

    final result = await showModalBottomSheet<MapLocationResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MapLocationPicker(
        title: 'Set Destination Location',
        initialLocation: initial,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _toLatitude = result.latitude;
        _toLongitude = result.longitude;
        _destinationCtrl.text = result.address;
      });
      _recalculatePrice();
    }
  }

  void _onPickupChanged(String value) {
    _pickupDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      if (_pickupSuggestions.isNotEmpty || _isSearchingPickup) {
        setState(() {
          _pickupSuggestions = [];
          _isSearchingPickup = false;
        });
      }
      return;
    }

    setState(() => _isSearchingPickup = true);
    _pickupDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await GebetaLocationService.searchPlaces(trimmed);
        if (mounted) {
          setState(() {
            _pickupSuggestions = results;
            _isSearchingPickup = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _pickupSuggestions = [];
            _isSearchingPickup = false;
          });
        }
      }
    });
  }

  void _selectPickupSuggestion(GebetaPlaceSuggestion item) {
    _pickupDebounce?.cancel();
    _pickupFocusNode.unfocus();
    setState(() {
      _pickupCtrl.text = item.displayText.isNotEmpty ? item.displayText : item.name;
      _fromLatitude = item.latitude;
      _fromLongitude = item.longitude;
      _pickupSuggestions = [];
      _isSearchingPickup = false;
    });
    _recalculatePrice();
  }

  void _onDestinationChanged(String value) {
    _destinationDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      if (_destinationSuggestions.isNotEmpty || _isSearchingDestination) {
        setState(() {
          _destinationSuggestions = [];
          _isSearchingDestination = false;
        });
      }
      return;
    }

    setState(() => _isSearchingDestination = true);
    _destinationDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await GebetaLocationService.searchPlaces(trimmed);
        if (mounted) {
          setState(() {
            _destinationSuggestions = results;
            _isSearchingDestination = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _destinationSuggestions = [];
            _isSearchingDestination = false;
          });
        }
      }
    });
  }

  void _selectDestinationSuggestion(GebetaPlaceSuggestion item) {
    _destinationDebounce?.cancel();
    _destinationFocusNode.unfocus();
    setState(() {
      _destinationCtrl.text = item.displayText.isNotEmpty ? item.displayText : item.name;
      _toLatitude = item.latitude;
      _toLongitude = item.longitude;
      _destinationSuggestions = [];
      _isSearchingDestination = false;
    });
    _recalculatePrice();
  }

  @override
  void dispose() {
    _pickupDebounce?.cancel();
    _destinationDebounce?.cancel();
    _pickupFocusNode.dispose();
    _destinationFocusNode.dispose();
    _pickupCtrl.dispose();
    _destinationCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    _kmPriceCtrl.dispose();
    _totalPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToNext() async {
    final dest = _destinationCtrl.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination address.')),
      );
      return;
    }
    final rawPhone = _phoneCtrl.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer phone number.')),
      );
      return;
    }

    _destinationDebounce?.cancel();
    _pickupDebounce?.cancel();
    _pickupFocusNode.unfocus();
    _destinationFocusNode.unfocus();

    // If destination coordinates were not selected from map or suggestions, try resolving them
    if (_toLatitude == null || _toLongitude == null) {
      try {
        final matches = await GebetaLocationService.searchPlaces(dest).timeout(
          const Duration(seconds: 2),
          onTimeout: () => [],
        );
        if (matches.isNotEmpty && mounted) {
          _toLatitude = matches.first.latitude;
          _toLongitude = matches.first.longitude;
        }
      } catch (_) {}
    }

    _recalculatePrice();
    if (mounted) {
      setState(() {
        _step = 1;
      });
    }
  }

  void _submit() {
    if (_destinationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination address.')),
      );
      return;
    }
    final rawPhone = _phoneCtrl.text.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer phone number.')),
      );
      return;
    }

    final formattedPhone = '${_selectedCountry.dialCode} ${rawPhone.replaceAll(RegExp(r'[^0-9]'), '')}';

    final kmPrice = double.tryParse(_kmPriceCtrl.text.trim()) ?? _pickupKmPrice;
    final totalPrice = double.tryParse(_totalPriceCtrl.text.trim()) ?? _pickupStartPrice;
    final int carTypeId = _carTypeId;

    widget.onCreateOrder(
      pickupAddress: _pickupCtrl.text.trim().isNotEmpty
          ? _pickupCtrl.text.trim()
          : 'Current Location, Addis Ababa',
      destinationAddress: _destinationCtrl.text.trim(),
      serviceCategory: _defaultService,
      customerPhone: formattedPhone,
      fromLatitude: _fromLatitude,
      fromLongitude: _fromLongitude,
      toLatitude: _toLatitude,
      toLongitude: _toLongitude,
      carTypeId: carTypeId,
      basePrice: _pickupStartPrice,
      kmPrice: kmPrice,
      totalKm: _calculatedDistanceKm,
      totalPrice: totalPrice,
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      fromFriendlyLocation: _pickupCtrl.text.split(',').first.trim(),
      toFriendlyLocation: _destinationCtrl.text.split(',').first.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: _step == 0
            ? _buildInputStep(context, isDark: isDark, inputBg: inputBg, textTheme: textTheme)
            : _buildSummaryStep(context, isDark: isDark, inputBg: inputBg, textTheme: textTheme),
      ),
    );
  }

  Widget _buildInputStep(
    BuildContext context, {
    required bool isDark,
    required Color inputBg,
    required TextTheme textTheme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handle
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Section: Departure / Pickup Header with "Set on map" action
        Row(
          children: [
            Expanded(
              child: Text(
                'Pickup (Departure)',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _isLoadingDeparture ? null : _initDepartureLocation,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.my_location_rounded, size: 13, color: AppColors.primary),
                    SizedBox(width: 3),
                    Text(
                      'Current GPS',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _pickDepartureOnMap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.map_rounded, size: 13, color: AppColors.primary),
                    SizedBox(width: 3),
                    Text(
                      'Set on map',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _pickupCtrl,
                  focusNode: _pickupFocusNode,
                  onChanged: _onPickupChanged,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: _isLoadingDeparture
                        ? 'Locating current position...'
                        : 'Departure location (e.g. Bole)',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_isLoadingDeparture || _isSearchingPickup)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                IconButton(
                  icon: const Icon(Icons.pin_drop_outlined, size: 18, color: AppColors.primary),
                  tooltip: 'Choose Departure on Map',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _pickDepartureOnMap,
                ),
            ],
          ),
        ),
        if (_pickupSuggestions.isNotEmpty)
          _buildSuggestionsDropdown(
            suggestions: _pickupSuggestions,
            onSelected: _selectPickupSuggestion,
            isDark: isDark,
          ),

        const SizedBox(height: 16),

        // Section: Destination
        Row(
          children: [
            Expanded(
              child: Text(
                'Destination',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _pickDestinationOnMap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.map_rounded, size: 13, color: AppColors.primary),
                    SizedBox(width: 3),
                    Text(
                      'Set on map',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.alt_route_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _destinationCtrl,
                  focusNode: _destinationFocusNode,
                  onChanged: _onDestinationChanged,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'Destination address (e.g. Bole)',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_isSearchingDestination)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                IconButton(
                  icon: const Icon(Icons.pin_drop_outlined, size: 18, color: AppColors.primary),
                  tooltip: 'Choose Destination on Map',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _pickDestinationOnMap,
                ),
            ],
          ),
        ),
        if (_destinationSuggestions.isNotEmpty)
          _buildSuggestionsDropdown(
            suggestions: _destinationSuggestions,
            onSelected: _selectDestinationSuggestion,
            isDark: isDark,
          ),

        const SizedBox(height: 16),

        // Customer Phone
        Text(
          'Customer Phone',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CountryCodeDropdown(
                selectedCountry: _selectedCountry,
                onChanged: (country) {
                  setState(() {
                    _selectedCountry = country;
                  });
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: _selectedCountry.dialCode == '+251'
                          ? '911 234 567'
                          : 'Phone number',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Description / Instructions
        Text(
          'Item Description / Notes',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.description_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _descCtrl,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Fragile electronics. Please call upon arrival.',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Actions: Cancel & Next (No pricing breakdown on input step)
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _goToNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryStep(
    BuildContext context, {
    required bool isDark,
    required Color inputBg,
    required TextTheme textTheme,
  }) {
    final pickupText = _pickupCtrl.text.trim().isNotEmpty
        ? _pickupCtrl.text.trim()
        : 'Current Location, Addis Ababa';
    final destText = _destinationCtrl.text.trim();
    final formattedPhone = '${_selectedCountry.dialCode} ${_phoneCtrl.text.trim()}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handle
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Header with Back button and Title
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _step = 0),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Trip Summary',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Route & Customer Info Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pickup
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.onlineGreen, width: 3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pickup',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pickupText,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  height: 16,
                  width: 2,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              // Destination
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destination',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          destText,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              // Customer Phone
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formattedPhone,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (_descCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _descCtrl.text.trim(),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Total KM & Total Price card (NO breakdown of km rate or base start price!)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Total KM
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.straighten_rounded,
                          size: 15,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Total km',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_calculatedDistanceKm > 0 ? _calculatedDistanceKm.toStringAsFixed(1) : "0.0"} km',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 16),
              // Total Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.payments_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Total Price',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_totalPriceCtrl.text} ETB',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Actions: Back & Create now
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _step = 0),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Create now',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestionsDropdown({
    required List<GebetaPlaceSuggestion> suggestions,
    required ValueChanged<GebetaPlaceSuggestion> onSelected,
    required bool isDark,
  }) {
    final dropdownBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      constraints: const BoxConstraints(maxHeight: 210),
      decoration: BoxDecoration(
        color: dropdownBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 1,
            color: borderColor.withValues(alpha: 0.6),
          ),
          itemBuilder: (context, index) {
            final item = suggestions[index];
            final subtitle = [item.city, item.country, item.type]
                .where((s) => s.trim().isNotEmpty)
                .join(' • ');

            return InkWell(
              onTap: () => onSelected(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
