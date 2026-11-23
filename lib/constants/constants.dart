import '../utils/currency_utils.dart';

const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.amnplc.com/api',
);

const String kSocketServerUrl = String.fromEnvironment(
  'SOCKET_SERVER_URL',
  defaultValue: 'https://amn-delivery-socket-server.onrender.com',
);

const String kAppName = 'AMN Driver';
const String kAppTagline = 'Deliver Fast, Earn More';
const String kCurrency = 'ETB';

/// Flag to toggle the visibility of the debug FCM Token card on Login and Profile screens.
/// Defaults to false so it is hidden even in debug mode unless explicitly enabled.
const bool kShowDebugFcmCard = bool.fromEnvironment(
  'SHOW_DEBUG_FCM_CARD',
  defaultValue: false,
);

/// Helper to format money consistently throughout AMN Driver with dynamic currency support.
String formatCurrency(num amount, {dynamic currency, int decimalDigits = 2}) {
  return CurrencyUtils.format(amount, currency: currency, decimalDigits: decimalDigits);
}

/// Helper to format money consistently throughout AMN Driver.
/// Backward-compatible with formatEtb while supporting optional dynamic currency.
String formatEtb(num amount, {dynamic currency, int decimalDigits = 2}) {
  return formatCurrency(amount, currency: currency ?? kCurrency, decimalDigits: decimalDigits);
}

