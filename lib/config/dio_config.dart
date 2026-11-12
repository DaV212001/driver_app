import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/constants.dart';
import '../constants/pages.dart';
import 'storage_config.dart';

class DioConfig {
  static bool isTestMode = false;
  static PersistCookieJar? cookieJar;
  static Dio? _dioInstance;

  static void resetDio() {
    _dioInstance = null;
    cookieJar = null;
  }

  static Future<Dio> dio() async {
    if (_dioInstance != null) return _dioInstance!;

    try {
      final directory = await getApplicationDocumentsDirectory();
      cookieJar ??= PersistCookieJar(
        storage: FileStorage('${directory.path}/.driver_cookies/'),
      );
    } catch (_) {
      // Fallback in test/headless environments
    }

    final client = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 120),
        headers: {'Accept': 'application/json'},
      ),
    );

    if (!isTestMode) {
      client.interceptors.addAll([
        LoggingInterceptor(),
        AuthInterceptor(),
      ]);
    }

    _dioInstance = client;
    return client;
  }

  static bool isSessionExpiredError(Object error) {
    return error is DioException &&
        error.message == 'Session expired. Please log in again.';
  }

  static String convertDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.sendTimeout:
        return 'Send timeout';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        if (data is Map && data.containsKey('message')) {
          return data['message'].toString();
        }
        return 'Server error ($statusCode)';
      case DioExceptionType.connectionError:
        return 'Network connection error. Please check your internet.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = StorageConfig.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      StorageConfig.clearSession();
      if (Get.currentRoute != Pages.login) {
        Get.offAllNamed(Pages.login);
      }
    }
    super.onError(err, handler);
  }
}

class LoggingInterceptor extends Interceptor {
  final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );

  String _formatPayload(dynamic data) {
    if (data == null) return '(empty)';
    if (data is FormData) {
      final fields = data.fields.map((e) => '${e.key}=${e.value}').join(', ');
      final files = data.files
          .map((e) => '${e.key}: File(${e.value.filename}, ${e.value.length} bytes)')
          .join(', ');
      return 'FormData {\n  fields: [$fields],\n  files: [$files]\n}';
    }
    if (data is Map || data is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(data);
      } catch (_) {
        return data.toString();
      }
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        return data;
      }
    }
    return data.toString();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final sb = StringBuffer();
    sb.writeln('➡️  [DIO REQUEST] ${options.method} ${options.uri}');
    if (options.headers.isNotEmpty) {
      sb.writeln('   Headers: ${options.headers}');
    }
    if (options.queryParameters.isNotEmpty) {
      sb.writeln('   Query Params: ${options.queryParameters}');
    }
    if (options.data != null) {
      sb.writeln('   Payload:');
      sb.writeln(_formatPayload(options.data));
    }
    _logger.i(sb.toString().trimRight());
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final sb = StringBuffer();
    sb.writeln('⬅️  [DIO RESPONSE] ${response.statusCode} ${response.statusMessage ?? ''} ${response.requestOptions.method} ${response.requestOptions.uri}');
    if (response.data != null) {
      sb.writeln('   Body:');
      sb.writeln(_formatPayload(response.data));
    }
    _logger.i(sb.toString().trimRight());
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final sb = StringBuffer();
    final status = err.response?.statusCode;
    sb.writeln('❌  [DIO ERROR ${status ?? 'NO_STATUS'}] ${err.requestOptions.method} ${err.requestOptions.uri}');
    sb.writeln('   Type: ${err.type}');
    sb.writeln('   Message: ${err.message}');
    if (err.requestOptions.data != null) {
      sb.writeln('   Request Payload:');
      sb.writeln(_formatPayload(err.requestOptions.data));
    }
    if (err.response?.data != null) {
      sb.writeln('   Response Body:');
      sb.writeln(_formatPayload(err.response?.data));
    }
    _logger.e(sb.toString().trimRight());
    super.onError(err, handler);
  }
}
