import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_sensors/http_client/errors.dart';
import 'package:live_sensors/http_client/open_id_api.dart';

void main() {
  const tokenEndpoint = 'https://example.test/token';

  test('refreshTokens reports invalid_grant as an expired refresh token',
      () async {
    final api = OpenIdApi(
      refreshPath: Uri.parse(tokenEndpoint),
      clientId: 'test-client',
      client: MockClient((request) async {
        return http.Response(
          '{"error":"invalid_grant","error_description":"Session not active"}',
          400,
        );
      }),
    );

    expect(
      api.refreshTokens('expired-refresh-token'),
      throwsA(
        isA<RefreshTokenExpiredException>().having(
          (error) => error.message,
          'message',
          'Session not active',
        ),
      ),
      reason: 'A real Keycloak invalid_grant must clear the saved session.',
    );
  });

  test('refreshTokens preserves session on transport failure', () async {
    final api = OpenIdApi(
      refreshPath: Uri.parse(tokenEndpoint),
      clientId: 'test-client',
      client: MockClient((request) async {
        throw http.ClientException('offline', request.url);
      }),
    );

    expect(
      api.refreshTokens('still-valid-refresh-token'),
      throwsA(isA<AuthBackendUnavailableException>()),
      reason: 'Offline startup is not proof that the refresh token expired.',
    );
  });
}
