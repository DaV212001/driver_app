class PickupOrderRequest {
  final double fromLatitude;
  final double fromLongitude;
  final double toLatitude;
  final double toLongitude;
  final String senderPhone;
  final int carTypeId;
  final double kmPrice;
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
    required this.kmPrice,
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
        'km_price': kmPrice,
        'total_price': totalPrice,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'from_friendly_location': fromFriendlyLocation,
        'to_friendly_location': toFriendlyLocation,
      };

  factory PickupOrderRequest.fromJson(Map<String, dynamic> json) =>
      PickupOrderRequest(
        fromLatitude: (json['from_latitude'] as num?)?.toDouble() ?? 0.0,
        fromLongitude: ((json['from_longtude'] ?? json['from_longitude'])
                    as num?)
                ?.toDouble() ??
            0.0,
        toLatitude: (json['to_latitude'] as num?)?.toDouble() ?? 0.0,
        toLongitude: ((json['to_longtude'] ?? json['to_longitude'])
                    as num?)
                ?.toDouble() ??
            0.0,
        senderPhone: json['sender_phone']?.toString() ?? '',
        carTypeId: (json['car_type_id'] as num?)?.toInt() ?? 1,
        kmPrice: (json['km_price'] as num?)?.toDouble() ?? 0.0,
        totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
        description: json['description']?.toString(),
        fromFriendlyLocation: json['from_friendly_location']?.toString() ?? '',
        toFriendlyLocation: json['to_friendly_location']?.toString() ?? '',
      );
}
