import '../utils/location_utils.dart';

class GebetaPlaceSuggestion {
  final String name;
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final String type;

  const GebetaPlaceSuggestion({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.city = '',
    this.country = '',
    this.type = '',
  });

  String get displayText {
    final parts = [name, city, country]
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return LocationUtils.prettifyAddress(parts.join(', '));
  }

  factory GebetaPlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString() ?? '';
    final rawCity = json['City']?.toString() ?? json['city']?.toString() ?? '';
    final rawCountry = json['Country']?.toString() ?? json['country']?.toString() ?? '';
    final rawType = json['type']?.toString() ?? '';

    return GebetaPlaceSuggestion(
      name: LocationUtils.prettifyAddress(rawName),
      latitude: (json['latitude'] as num?)?.toDouble() ??
          double.tryParse(json['latitude']?.toString() ?? '') ??
          0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          double.tryParse(json['longitude']?.toString() ?? '') ??
          0.0,
      city: LocationUtils.prettifyAddress(rawCity),
      country: LocationUtils.prettifyAddress(rawCountry),
      type: LocationUtils.prettifyAddress(rawType),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'City': city,
        'Country': country,
        'type': type,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GebetaPlaceSuggestion &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => name.hashCode ^ latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() =>
      'GebetaPlaceSuggestion(name: $name, lat: $latitude, lng: $longitude, city: $city, type: $type)';
}
