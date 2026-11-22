import 'package:dio/dio.dart';
import 'config.dart';

typedef TokenGetter = Future<String?> Function();

Dio buildDio({required TokenGetter token, required void Function() onUnauthorized}) {
  final dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    contentType: 'application/json',
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (o, h) async {
      final t = await token();
      if (t != null) o.headers['Authorization'] = 'Bearer $t';
      h.next(o);
    },
    onError: (e, h) {
      final path = e.requestOptions.path;
      if (e.response?.statusCode == 401 && !path.startsWith('/auth/login') && !path.startsWith('/auth/register')) {
        onUnauthorized();
      }
      h.next(e);
    },
  ));
  return dio;
}

/// Human-readable message from a Dio error / backend { error } body.
String apiError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] != null) {
      final err = d['error'];
      final det = d['details'];
      if (det is List && det.isNotEmpty && det.first is Map) {
        return '${det.first['path']}: ${det.first['message']}';
      }
      if (err is String) return err;
      if (err is Map && err['message'] != null) return err['message'].toString();
      return err.toString();
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'No connection to server';
    }
    return e.message ?? 'Request failed';
  }
  return e.toString();
}
