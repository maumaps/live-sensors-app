import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:live_sensors/entities/tokens.dart';
import 'package:live_sensors/http_client/errors.dart';
import 'package:live_sensors/http_client/open_id_api.dart';
import 'package:live_sensors/http_client/open_id_client.dart';

class _ProtectedResourceClient extends http.BaseClient {
  final Tokens initialTokens;
  int protectedRequestCount = 0;

  _ProtectedResourceClient({required this.initialTokens});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    protectedRequestCount++;
    if (protectedRequestCount == 1) {
      expect(
        request.headers['Authorization'],
        'Bearer ${initialTokens.accessToken}',
        reason: 'The first protected request should use restored tokens.',
      );
      return http.StreamedResponse(Stream.value(<int>[]), 401);
    }

    expect(
      request.headers['Authorization'],
      'Bearer refreshed-access-token',
      reason: 'The retry should carry the refreshed access token.',
    );
    return http.StreamedResponse(Stream.value(<int>[]), 200);
  }
}

Tokens _tokens({
  String sessionId = 'session',
  String refreshToken = 'refresh-token',
  String accessToken = 'access-token',
}) {
  return Tokens(
    sessionId: sessionId,
    refreshToken: refreshToken,
    accessToken: accessToken,
    expiresIn: 180,
    refreshExpiresIn: 3600,
  );
}

http.Response _refreshResponse({
  String sessionId = 'refreshed-session',
  String refreshToken = 'refreshed-refresh-token',
  String accessToken = 'refreshed-access-token',
}) {
  return http.Response(
    '''
{
  "session_state": "$sessionId",
  "expires_in": 180,
  "refresh_expires_in": 3600,
  "refresh_token": "$refreshToken",
  "access_token": "$accessToken"
}
''',
    200,
  );
}

void main() {
  const tokenEndpoint = 'https://example.test/token';

  test('loginByTokens keeps the restored session when refresh is offline',
      () async {
    final restoredTokens = _tokens();
    Tokens? loggedInTokens;
    var loggedOut = false;

    final client = OpenIdClient(
      OpenIdApi(
        refreshPath: Uri.parse(tokenEndpoint),
        clientId: 'test-client',
        client: MockClient((request) async {
          throw http.ClientException('offline', request.url);
        }),
      ),
      inner: MockClient((request) async => http.Response('', 200)),
      postLogin: (tokens) => loggedInTokens = tokens,
      postLogout: () => loggedOut = true,
      postRefresh: (_) {},
    );

    await expectLater(
      client.loginByTokens(restoredTokens),
      throwsA(isA<AuthBackendUnavailableException>()),
      reason: 'Offline startup should surface degraded auth, not erase state.',
    );
    client.stopRefreshCycle();

    expect(
      loggedInTokens,
      same(restoredTokens),
      reason: 'The app should remain usable offline with its restored tokens.',
    );
    expect(
      loggedOut,
      isFalse,
      reason: 'Transport failures must not drop the secure-storage session.',
    );
  });

  test('send refreshes once after a 401 and retries with the new access token',
      () async {
    final initialTokens = _tokens();
    Tokens? refreshedTokens;
    var loggedOut = false;
    final protectedResourceClient = _ProtectedResourceClient(
      initialTokens: initialTokens,
    );

    final authApi = OpenIdApi(
      refreshPath: Uri.parse(tokenEndpoint),
      clientId: 'test-client',
      client: MockClient((request) async {
        expect(
          request.bodyFields['refresh_token'],
          initialTokens.refreshToken,
          reason: 'The refresh request should use the current refresh token.',
        );
        return _refreshResponse();
      }),
    );

    final client = OpenIdClient(
      authApi,
      inner: protectedResourceClient,
      postLogin: (_) {},
      postLogout: () => loggedOut = true,
      postRefresh: (tokens) => refreshedTokens = tokens,
    );
    client.tokens = initialTokens;

    final response = await client.send(
      http.Request('GET', Uri.parse('https://example.test/protected')),
    );

    expect(
      response.statusCode,
      200,
      reason: 'A single stale access token should be repaired transparently.',
    );
    expect(
      protectedResourceClient.protectedRequestCount,
      2,
      reason: 'The client should retry the protected request once.',
    );
    expect(
      refreshedTokens?.accessToken,
      'refreshed-access-token',
      reason: 'Successful refresh should be persisted by the caller hook.',
    );
    expect(
      loggedOut,
      isFalse,
      reason: 'A successful refresh must not clear the active session.',
    );
  });
}
