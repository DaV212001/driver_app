import 'dart:async';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../config/dio_config.dart';

class DioService {
  static const int _maxGetAttempts = 2;
  static const Duration _maxRetryDelay = Duration(seconds: 5);

  static bool _shouldRetry(DioException error) {
    final data = error.response?.data;
    return error.response?.statusCode == 520 ||
        (data is Map && data['retryable'] == true);
  }

  static Duration _retryDelay(DioException error, int attempt) {
    final value = error.response?.data is Map
        ? error.response?.data['retry_after']
        : null;
    final seconds = value is num ? value.toInt() : attempt * 2;
    final delay = Duration(seconds: seconds);
    return delay > _maxRetryDelay ? _maxRetryDelay : delay;
  }

  static Future<Response> _getWithRetry({
    required String path,
    Options? options,
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await (await DioConfig.dio()).get(
          path,
          options: options,
          data: data,
          queryParameters: queryParameters,
        );
      } on DioException catch (error) {
        attempt++;
        if (attempt >= _maxGetAttempts || !_shouldRetry(error)) rethrow;
        final delay = _retryDelay(error, attempt);
        Logger().w('Retrying GET $path after ${delay.inSeconds}s');
        await Future.delayed(delay);
      }
    }
  }

  static Future<void> dioGet({
    required String path,
    Options? options,
    Object? data,
    Map<String, dynamic>? queryParameters,
    FutureOr<void> Function(Response response)? onSuccess,
    FutureOr<void> Function(Object error, Response response)? onFailure,
  }) async {
    var response = Response(requestOptions: RequestOptions());
    try {
      response = await _getWithRetry(
        path: path,
        options: options,
        data: data,
        queryParameters: queryParameters,
      );
      if (response.statusCode == 200) {
        await onSuccess?.call(response);
      } else {
        await onFailure?.call(response.statusCode!, response);
      }
    } catch (error, stack) {
      Logger().e('GET $path failed', error: error, stackTrace: stack);
      final res = (error is DioException && error.response != null)
          ? error.response!
          : response;
      await onFailure?.call(error, res);
    }
  }

  static Future<void> dioPost({
    required String path,
    Options? options,
    Object? data,
    FutureOr<void> Function(Response response)? onSuccess,
    FutureOr<void> Function(Object error, Response response)? onFailure,
  }) async {
    var response = Response(requestOptions: RequestOptions());
    try {
      response = await (await DioConfig.dio()).post(
        path,
        options: options,
        data: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await onSuccess?.call(response);
      } else {
        await onFailure?.call(response.statusCode!, response);
      }
    } catch (error, stack) {
      Logger().e('POST $path failed', error: error, stackTrace: stack);
      final res = (error is DioException && error.response != null)
          ? error.response!
          : response;
      await onFailure?.call(error, res);
    }
  }

  static Future<void> dioPut({
    required String path,
    Options? options,
    Object? data,
    FutureOr<void> Function(Response response)? onSuccess,
    FutureOr<void> Function(Object error, Response response)? onFailure,
  }) async {
    var response = Response(requestOptions: RequestOptions());
    try {
      response = await (await DioConfig.dio()).put(
        path,
        options: options,
        data: data,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await onSuccess?.call(response);
      } else {
        await onFailure?.call(response.statusCode!, response);
      }
    } catch (error, stack) {
      Logger().e('PUT $path failed', error: error, stackTrace: stack);
      final res = (error is DioException && error.response != null)
          ? error.response!
          : response;
      await onFailure?.call(error, res);
    }
  }

  static Future<void> dioDelete({
    required String path,
    Options? options,
    Object? data,
    FutureOr<void> Function(Response response)? onSuccess,
    FutureOr<void> Function(Object error, Response response)? onFailure,
  }) async {
    var response = Response(requestOptions: RequestOptions());
    try {
      response = await (await DioConfig.dio()).delete(
        path,
        options: options,
        data: data,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await onSuccess?.call(response);
      } else {
        await onFailure?.call(response.statusCode!, response);
      }
    } catch (error, stack) {
      Logger().e('DELETE $path failed', error: error, stackTrace: stack);
      final res = (error is DioException && error.response != null)
          ? error.response!
          : response;
      await onFailure?.call(error, res);
    }
  }

  static Future<void> dioUpload({
    required String path,
    required FormData formData,
    Options? options,
    FutureOr<void> Function(Response response)? onSuccess,
    FutureOr<void> Function(Object error, Response response)? onFailure,
  }) async {
    var response = Response(requestOptions: RequestOptions());
    try {
      response = await (await DioConfig.dio()).post(
        path,
        options: options,
        data: formData,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await onSuccess?.call(response);
      } else {
        await onFailure?.call(response.statusCode!, response);
      }
    } catch (error, stack) {
      Logger().e('UPLOAD $path failed', error: error, stackTrace: stack);
      final res = (error is DioException && error.response != null)
          ? error.response!
          : response;
      await onFailure?.call(error, res);
    }
  }
}
