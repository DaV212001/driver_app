class CurrencyModel {
  final int id;
  final String code;
  final String symbol;
  final String name;

  const CurrencyModel({
    required this.id,
    required this.code,
    this.symbol = '',
    this.name = '',
  });

  factory CurrencyModel.fromJson(Map<String, dynamic> json) {
    return CurrencyModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      code: (json['code'] ?? json['currency_code'] ?? 'ETB').toString().trim(),
      symbol: (json['symbol'] ?? json['currency_symbol'] ?? '').toString().trim(),
      name: (json['name'] ?? json['currency_name'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'symbol': symbol,
        'name': name,
      };
}
