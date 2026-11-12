class DeliveryPriceModel {
  final int id;
  final int cityId;
  final int? currencyId;
  final int carTypeId;
  final double propertyStartPrice;
  final double propertyKmPrice;
  final double courierStartPrice;
  final double courierKmPrice;
  final double pickupStartPrice;
  final double pickupKmPrice;
  final String? createdAt;
  final String? updatedAt;

  const DeliveryPriceModel({
    required this.id,
    required this.cityId,
    this.currencyId,
    required this.carTypeId,
    this.propertyStartPrice = 0.0,
    this.propertyKmPrice = 0.0,
    this.courierStartPrice = 0.0,
    this.courierKmPrice = 0.0,
    this.pickupStartPrice = 0.0,
    this.pickupKmPrice = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  factory DeliveryPriceModel.fromJson(Map<String, dynamic> json) {
    return DeliveryPriceModel(
      id: _parseInt(json['id']),
      cityId: _parseInt(json['city_id'], 1),
      currencyId: json['currency_id'] != null ? _parseInt(json['currency_id']) : null,
      carTypeId: _parseInt(json['car_type_id'], 1),
      propertyStartPrice: _parseDouble(json['property_start_price']),
      propertyKmPrice: _parseDouble(json['property_km_price']),
      courierStartPrice: _parseDouble(
        json['courirer_start_price'] ?? json['courier_start_price'],
      ),
      courierKmPrice: _parseDouble(
        json['courirer_km_price'] ?? json['courier_km_price'],
      ),
      pickupStartPrice: _parseDouble(json['pickup_start_price']),
      pickupKmPrice: _parseDouble(json['pickup_km_price']),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'city_id': cityId.toString(),
        'currency_id': currencyId?.toString(),
        'car_type_id': carTypeId.toString(),
        'property_start_price': propertyStartPrice.toString(),
        'property_km_price': propertyKmPrice.toString(),
        'courirer_start_price': courierStartPrice.toString(),
        'courirer_km_price': courierKmPrice.toString(),
        'pickup_start_price': pickupStartPrice.toString(),
        'pickup_km_price': pickupKmPrice.toString(),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
