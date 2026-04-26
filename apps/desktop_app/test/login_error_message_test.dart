import 'package:desktop_app/ui/auth/login_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const backendUrl = 'http://localhost:3000';

  test('login error explains backend connectivity failures', () {
    final message = loginFailureMessage(
      DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.connectionError,
        error: 'connection refused',
      ),
      backendUrl,
    );

    expect(message, contains('Cannot reach the backend'));
    expect(message, contains(backendUrl));
  });

  test('login error preserves invalid credential failures', () {
    final message = loginFailureMessage(
      DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
        ),
      ),
      backendUrl,
    );

    expect(message, 'Invalid email or password.');
  });
}
