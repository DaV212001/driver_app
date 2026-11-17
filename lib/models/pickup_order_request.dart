class PickupOrderRequest {
  final double fromLatitude;
  final double fromLongitude;
  final double toLatitude;
  final double toLongitude;
  final String senderPhone;
  final int carTypeId;
  final double basePrice;
  final double kmPrice;
  final double totalKm;
  final double totalPrice;
  final String? description;
  final String fromFriendlyLocation;
  final String toFriendlyLocation;

  const PickupOrderRequest({
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toLatitude,
    required this.toLongitude,
    required this.senderPhone,
    required this.carTypeId,
    this.basePrice = 0.0,
    required this.kmPrice,
    this.totalKm = 0.0,
    required this.totalPrice,
    this.description,
    required this.fromFriendlyLocation,
    required this.toFriendlyLocation,
  });

  Map<String, dynamic> toJson() => {
        'from_latitude': fromLatitude,
        'from_longtude': fromLongitude,
        'to_latitude': toLatitude,
        'to_longtude': toLongitude,
        'sender_phone': senderPhone,
        'car_type_id': carTypeId,
        'base_price': basePrice,
        'km_price': kmPrice,
        'total_km': totalKm,
        'total_price': totalPrice,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'from_friendly_location': fromFriendlyLocation,
        'to_friendly_location': toFriendlyLocation,
      };

  factory PickupOrderRequest.fromJson(Map<String, dynamic> json) =>
      PickupOrderRequest(
        fromLatitude: (json['from_latitude'] as num?)?.toDouble() ??
            (double.tryParse(json['from_latitude']?.toString() ?? '')) ??
            0.0,
        fromLongitude: ((json['from_longtude'] ?? json['from_longitude'])
                    as num?)
                ?.toDouble() ??
            (double.tryParse((json['from_longtude'] ?? json['from_longitude'])
                    ?.toString() ??
                '')) ??
            0.0,
        toLatitude: (json['to_latitude'] as num?)?.toDouble() ??
            (double.tryParse(json['to_latitude']?.toString() ?? '')) ??
            0.0,
        toLongitude: ((json['to_longtude'] ?? json['to_longitude'])
                    as num?)
                ?.toDouble() ??
            (double.tryParse((json['to_longtude'] ?? json['to_longitude'])
                    ?.toString() ??
                '')) ??
            0.0,
        senderPhone: json['sender_phone']?.toString() ?? '',
        carTypeId: (json['car_type_id'] as num?)?.toInt() ??
            (int.tryParse(json['car_type_id']?.toString() ?? '')) ??
            1,
        basePrice: (json['base_price'] as num?)?.toDouble() ??
            (json['start_price'] as num?)?.toDouble() ??
            (double.tryParse(json['base_price']?.toString() ??
                json['start_price']?.toString() ??
                '')) ??
            0.0,
        kmPrice: (json['km_price'] as num?)?.toDouble() ??
            (double.tryParse(json['km_price']?.toString() ?? '')) ??
            0.0,
        totalKm: (json['total_km'] as num?)?.toDouble() ??
            (double.tryParse(json['total_km']?.toString() ?? '')) ??
            0.0,
        totalPrice: (json['total_price'] as num?)?.toDouble() ??
            (double.tryParse(json['total_price']?.toString() ?? '')) ??
            0.0,
        description: json['description']?.toString(),
        fromFriendlyLocation: json['from_friendly_location']?.toString() ?? '',
        toFriendlyLocation: json['to_friendly_location']?.toString() ?? '',
      );
}
