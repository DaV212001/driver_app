import '../models/currency_model.dart';

class CurrencyUtils {
  static final Map<String, String> _codeMap = {
    '1': 'ETB',
    '2': 'AED',
    '3': 'USD',
    '4': 'Yuan',
  };

  static final Map<String, String> _symbolMap = {
    '1': 'Br',
    '2': 'AED',
    '3': r'$',
    '4': 'Yuan',
    'etb': 'Br',
    'br': 'Br',
    'birr': 'Br',
    'aed': 'AED',
    'usd': r'$',
    'yuan': 'Yuan',
    'cny': '¥',
    'eur': '€',
    'gbp': '£',
    'btc': '₿',
  };

  /// Register or update dynamic currencies fetched from the backend.
  static void registerCurrencies(List<dynamic> currencies) {
    for (final c in currencies) {
      if (c is CurrencyModel) {
        final idStr = c.id.toString();
        final codeKey = c.code.trim().toLowerCase();
        if (c.code.trim().isNotEmpty) {
          _codeMap[idStr] = c.code.trim();
          _codeMap[codeKey] = c.code.trim();
        }
        if (c.symbol.trim().isNotEmpty) {
          _symbolMap[idStr] = c.symbol.trim();
          _symbolMap[codeKey] = c.symbol.trim();
        }
      } else if (c is Map<String, dynamic>) {
        final model = CurrencyModel.fromJson(c);
        registerCurrencies([model]);
      }
    }
  }

  /// Resolves currency input (ID, code, or symbol) to canonical display code (e.g., 'ETB', 'USD', 'AED', 'Yuan').
  /// If [raw] is null or empty, returns [fallback].
  /// If [raw] matches a known numeric ID (e.g. 1 -> ETB, 2 -> AED, 3 -> USD, 4 -> Yuan), returns the mapped code.
  /// Otherwise preserves the currency string (e.g. '$', 'EUR', 'ETB', etc.).
  static String resolveCode(dynamic raw, {String fallback = 'ETB'}) {
    if (raw == null) return fallback;
    final s = raw.toString().trim();
    if (s.isEmpty) return fallback;
    final lower = s.toLowerCase();
    if (_codeMap.containsKey(lower)) {
      return _codeMap[lower]!;
    }
    return s;
  }

  /// Resolves currency input (ID, code, or symbol) to canonical symbol (e.g., 'Br', '$', 'AED', 'Yuan').
  static String resolveSymbol(dynamic raw, {String fallback = 'Br'}) {
    if (raw == null) return fallback;
    final s = raw.toString().trim();
    if (s.isEmpty) return fallback;
    final lower = s.toLowerCase();
    if (_symbolMap.containsKey(lower)) {
      return _symbolMap[lower]!;
    }
    return s;
  }

  /// Formats price with dynamic currency code (e.g. "ETB 150.00" or "USD 25.00").
  static String format(
    num price, {
    dynamic currency,
    int decimalDigits = 2,
    bool prefix = true,
    String fallback = 'ETB',
  }) {
    final code = resolveCode(currency, fallback: fallback);
    final formattedNum = price.toStringAsFixed(decimalDigits);
    return prefix ? '$code $formattedNum' : '$formattedNum $code';
  }

  /// Resolves currency input (code, symbol, or ID) to canonical numeric ID (e.g. 'USD' -> 3, 'ETB' -> 1, 'AED' -> 2, 'Yuan' -> 4).
  static int? resolveId(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final parsed = int.tryParse(s);
    if (parsed != null && _codeMap.containsKey(parsed.toString())) {
      return parsed;
    }
    final lower = s.toLowerCase();
    for (final entry in _codeMap.entries) {
      if (int.tryParse(entry.key) != null && entry.value.toLowerCase() == lower) {
        return int.parse(entry.key);
      }
    }
    for (final entry in _symbolMap.entries) {
      if (int.tryParse(entry.key) != null && entry.value.toLowerCase() == lower) {
        return int.parse(entry.key);
      }
    }
    return null;
  }
}
