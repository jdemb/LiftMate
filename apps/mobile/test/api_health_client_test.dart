import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liftmate/api_health_client.dart';

void main() {
  group('ApiHealthClient', () {
    test('returns online for 200 ok health response', () async {
      final client = ApiHealthClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://api.example.test/health');

          return http.Response('{"status":"ok"}', 200);
        }),
      );

      final result = await client.check();

      expect(result.status, ApiHealthStatus.online);
      expect(result.checkedUri.toString(), 'https://api.example.test/health');
      expect(result.message, contains('reachable'));
    });

    test('does not duplicate slash when base URL has trailing slash', () async {
      final client = ApiHealthClient(
        baseUrl: 'https://api.example.test/',
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'https://api.example.test/health');

          return http.Response('{"status":"ok"}', 200);
        }),
      );

      final result = await client.check();

      expect(result.status, ApiHealthStatus.online);
    });

    test('returns offline for non-200 response', () async {
      final client = ApiHealthClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          return http.Response('Service unavailable', 503);
        }),
      );

      final result = await client.check();

      expect(result.status, ApiHealthStatus.offline);
      expect(result.statusCode, 503);
      expect(result.message, contains('503'));
    });

    test('returns offline for unexpected health status body', () async {
      final client = ApiHealthClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          return http.Response('{"status":"degraded"}', 200);
        }),
      );

      final result = await client.check();

      expect(result.status, ApiHealthStatus.offline);
      expect(result.message, contains('degraded'));
    });

    test('returns error for malformed JSON', () async {
      final client = ApiHealthClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          return http.Response('not json', 200);
        }),
      );

      final result = await client.check();

      expect(result.status, ApiHealthStatus.error);
      expect(result.message, contains('Invalid health response'));
    });

    test('returns error for thrown client exception', () async {
      final client = ApiHealthClient(
        baseUrl: 'https://api.example.test',
        httpClient: MockClient((request) async {
          throw http.ClientException('connection failed', request.url);
        }),
      );

      final result = await client.check();

      expect(result.status, ApiHealthStatus.error);
      expect(result.message, contains('connection failed'));
    });

    test('returns error when API base URL is not configured', () async {
      final client = ApiHealthClient(
        baseUrl: '',
        httpClient: MockClient((request) async {
          fail('HTTP client should not be called without a base URL');
        }),
      );

      final result = await client.check();

      expect(result.status, ApiHealthStatus.error);
      expect(result.checkedUri, isNull);
      expect(result.message, contains('API_BASE_URL'));
    });

    test('returns error for timeout', () async {
      final client = ApiHealthClient(
        baseUrl: 'https://api.example.test',
        timeout: const Duration(milliseconds: 1),
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 25));

          return http.Response('{"status":"ok"}', 200);
        }),
      );

      final result = await client.check();

      expect(result.status, ApiHealthStatus.error);
      expect(result.message, contains('timed out'));
    });
  });
}
