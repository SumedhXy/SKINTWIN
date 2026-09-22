import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:skintwin/core/services/comparison_service.dart';
import 'package:skintwin/core/network/dio_client.dart';
import 'package:skintwin/core/models/api_models.dart';

class MockDioClient implements DioClient {
  final Dio _dio;
  MockDioClient(this._dio);

  @override
  Dio get dio => _dio;
}

class ThrowInterceptor extends Interceptor {
  final DioException exception;

  ThrowInterceptor(this.exception);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(exception, true);
  }
}

void main() {
  group('ComparisonService Error Handling Tests (Timeout & Auth)', () {
    late Dio dio;
    late ComparisonService service;

    setUp(() {
      dio = Dio();
      service = ComparisonService(dioClient: MockDioClient(dio));
    });

    test('Throws timeout exception when receiveTimeout occurs', () async {
      dio.interceptors.add(ThrowInterceptor(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.receiveTimeout,
        ),
      ));

      final req = ComparisonCreateRequest(
        earlierCaptureId: 'cap1',
        latestCaptureId: 'cap2',
      );

      expect(
        () => service.createComparison(publicId: 'tw_123', request: req),
        throwsA(predicate((e) => e.toString().contains('The request timed out. Please try again.'))),
      );
    });

    test('Throws unauthorized exception when 401 occurs (Expired JWT)', () async {
      dio.interceptors.add(ThrowInterceptor(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 401,
            data: {'detail': 'Token expired'},
          ),
        ),
      ));

      expect(
        () => service.getComparison('comp_123'),
        throwsA(predicate((e) => e.toString().contains('Unauthorized session. Please log in again.'))),
      );
    });

    test('Throws too many requests exception when 429 occurs', () async {
      dio.interceptors.add(ThrowInterceptor(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 429,
            data: {'detail': 'Too many requests'},
          ),
        ),
      ));

      expect(
        () => service.getComparisons('tw_123'),
        throwsA(predicate((e) => e.toString().contains('Too many requests. Please wait a moment.'))),
      );
    });
  });
}
