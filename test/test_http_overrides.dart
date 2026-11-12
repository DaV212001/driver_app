import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _MockHttpClient();
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = false;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  void add(List<int> data) {}

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  String? value(String name) {
    final list = _headers[name.toLowerCase()];
    return (list != null && list.isNotEmpty) ? list.last : null;
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }
}

final _transparent1x1Png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _MockHttpClientResponse extends StreamView<List<int>> implements HttpClientResponse {
  _MockHttpClientResponse() : super(Stream<List<int>>.value(_transparent1x1Png));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  int get contentLength => _transparent1x1Png.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => true;
}
