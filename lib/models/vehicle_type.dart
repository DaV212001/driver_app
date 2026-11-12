class VehicleTypeModel {
  final int id;
  final String name;
  final String? image;
  final String? status;
  final double propertyKmPrice;
  final double courierStartPrice;
  final double courierKmPrice;
  final String? isCourier;

  const VehicleTypeModel({
    required this.id,
    required this.name,
    this.image,
    this.status,
    this.propertyKmPrice = 0.0,
    this.courierStartPrice = 0.0,
    this.courierKmPrice = 0.0,
    this.isCourier,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString(),
      status: json['status']?.toString(),
      propertyKmPrice: _parseDouble(json['property_km_price']),
      courierStartPrice: _parseDouble(
        json['courirer_start_price'] ?? json['courier_start_price'],
      ),
      courierKmPrice: _parseDouble(
        json['courirer_km_price'] ?? json['courier_km_price'],
      ),
      isCourier: json['is_courirer']?.toString() ?? json['is_courier']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'status': status,
        'property_km_price': propertyKmPrice.toString(),
        'courirer_start_price': courierStartPrice.toString(),
        'courirer_km_price': courierKmPrice.toString(),
        'is_courirer': isCourier,
      };
}
