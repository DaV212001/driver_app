class CityModel {
  final int id;
  final String name;
  final String? status;

  const CityModel({
    required this.id,
    required this.name,
    this.status,
  });

  /// Canonical mapping between city names and database IDs.
  /// The backend GET /city endpoint does not return id fields in its payload,
  /// so this mapping guarantees accurate backend foreign keys across AMN services.
  static const Map<String, int> nameToIdMap = {
    'addis ababa': 1,
    'hawassa': 2,
    'harar': 4,
    'mizan teferi': 5,
    'dilla': 6,
    'united arab emirates': 7,
    'turkey': 8,
    'uganda': 9,
    'bahir dar': 10,
    'debrebirhan': 11,
    'shashamene': 12,
    'jijiga': 13,
    'dire dewa': 14,
    'dire dawa': 14,
    'adama': 15,
    'adama (nazret)': 15,
    'bishoftu': 16,
    'djibouti': 17,
  };

  factory CityModel.fromJson(Map<String, dynamic> json, [int fallbackIndex = 0]) {
    final rawName = json['name']?.toString() ?? '';
    final normalized = rawName.trim().toLowerCase();
    final mappedId = nameToIdMap[normalized];

    final rawId = json['id'] ?? json['city_id'];
    int parsedId = rawId is int
        ? rawId
        : (int.tryParse(rawId?.toString() ?? '') ?? 0);

    if (parsedId <= 0 && mappedId != null) {
      parsedId = mappedId;
    }
    if (parsedId <= 0 && fallbackIndex > 0) {
      parsedId = fallbackIndex;
    }

    return CityModel(
      id: parsedId,
      name: rawName,
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$name (ID: $id)';
}
