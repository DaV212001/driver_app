import '../config/storage_config.dart';

class VehicleInfo {
  final String type; // MoterBick, Bajaj, Car, etc.
  final String model;
  final String plateNumber;
  final bool isVerified;
  final int? vehicleId;
  final String? imageUrl;

  VehicleInfo({
    required this.type,
    required this.model,
    required this.plateNumber,
    this.isVerified = true,
    this.vehicleId,
    this.imageUrl,
  });

  VehicleInfo copyWith({
    String? type,
    String? model,
    String? plateNumber,
    bool? isVerified,
    int? vehicleId,
    String? imageUrl,
  }) {
    return VehicleInfo(
      type: type ?? this.type,
      model: model ?? this.model,
      plateNumber: plateNumber ?? this.plateNumber,
      isVerified: isVerified ?? this.isVerified,
      vehicleId: vehicleId ?? this.vehicleId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class DriverProfile {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String avatarUrl;
  final double rating;
  final int totalTrips;
  final String tier; // Gold Courier, Platinum, etc.
  final VehicleInfo vehicle;
  final String bankName;
  final String bankAccountNumber;
  final double walletAmount;
  bool autoAcceptOrders;
  String navigationApp;
  final String? cityId;

  DriverProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.avatarUrl,
    required this.rating,
    required this.totalTrips,
    required this.tier,
    required this.vehicle,
    required this.bankName,
    required this.bankAccountNumber,
    this.walletAmount = 0.0,
    this.autoAcceptOrders = false,
    this.navigationApp = 'Google Maps',
    this.cityId,
  });

  factory DriverProfile.fromStorage() {
    final name = StorageConfig.getDriverName() ?? '';
    final phone = StorageConfig.getDriverPhone() ?? '';
    final email = StorageConfig.getDriverEmail() ?? '';
    final avatar = StorageConfig.getDriverAvatar() ?? '';
    final id = StorageConfig.getDriverId() ?? '';
    final vehicleIdStr = StorageConfig.getDriverVehicleId();
    final vehicleId = vehicleIdStr != null ? int.tryParse(vehicleIdStr) : null;
    final plate = StorageConfig.getDriverPlateNumber() ?? '';
    final vehicleName = StorageConfig.getDriverVehicleName() ?? '';
    final vehicleImage = StorageConfig.getDriverVehicleImage();
    final cityId = StorageConfig.getDriverCityId();

    final displayName = vehicleName.isNotEmpty
        ? vehicleName
        : (vehicleId != null ? 'Vehicle #$vehicleId' : '');

    return DriverProfile(
      id: id,
      name: name,
      phone: phone,
      email: email,
      avatarUrl: avatar,
      rating: 5.0,
      totalTrips: 0,
      tier: 'Courier',
      vehicle: VehicleInfo(
        type: displayName,
        model: displayName,
        plateNumber: plate,
        isVerified: plate.isNotEmpty || vehicleId != null,
        vehicleId: vehicleId,
        imageUrl: vehicleImage,
      ),
      bankName: '',
      bankAccountNumber: '',
      walletAmount: 0.0,
      autoAcceptOrders: StorageConfig.getAutoAccept(),
      navigationApp: StorageConfig.getNavApp(),
      cityId: cityId,
    );
  }

  factory DriverProfile.empty() => DriverProfile.fromStorage();

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : '';
  }

  String get lastName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  DriverProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? avatarUrl,
    double? rating,
    int? totalTrips,
    String? tier,
    VehicleInfo? vehicle,
    String? bankName,
    String? bankAccountNumber,
    double? walletAmount,
    bool? autoAcceptOrders,
    String? navigationApp,
    String? cityId,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      tier: tier ?? this.tier,
      vehicle: vehicle ?? this.vehicle,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      walletAmount: walletAmount ?? this.walletAmount,
      autoAcceptOrders: autoAcceptOrders ?? this.autoAcceptOrders,
      navigationApp: navigationApp ?? this.navigationApp,
      cityId: cityId ?? this.cityId,
    );
  }
}
