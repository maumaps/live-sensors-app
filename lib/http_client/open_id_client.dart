import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:live_sensors/entities/tokens.dart';
import 'package:live_sensors/http_client/utils.dart';
import 'errors.dart';
import 'open_id_api.dart';

class OpenIdClient extends http.BaseClient {
  final http.Client _inner;
  final OpenIdApi openIdApi;
  final void Function(Tokens) postLogin;
  final void Function() postLogout;
  final void Function(Tokens) postRefresh;
  Tokens? _tokens;

  OpenIdClient(
    this.openIdApi, {
    http.Client? inner,
    required this.postLogin,
    required this.postLogout,
    required this.postRefresh,
  }) : _inner = inner ?? http.Client();

  static String _getAuthString(Tokens tokens) {
    String? accessToken = tokens.accessToken;
    return 'Bearer $accessToken';
  }

  // Tokens getter / setter
  set tokens(Tokens t) {
    _tokens = t;
  }

  Tokens get tokens {
    Tokens? t = _tokens;
    if (t != null) {
      return t;
    }
    throw Error();
  }

  clearTokens() {
    _tokens = null;
  }

  /// Debounce update token requests.
  /// All request that comes when update request active - wait this request
  /// Instead of create new one
  Future<Tokens>? _updateTokensActiveRequest;
  Future<Tokens> _tokensUpdated() {
    if (_updateTokensActiveRequest != null) {
      return _updateTokensActiveRequest!;
    }

    final refreshToken = _tokens?.refreshToken;
    if (refreshToken == null) {
      throw ErrorDescription('Refresh token missing');
    }

    _updateTokensActiveRequest = _updateTokens(refreshToken).whenComplete(() {
      _updateTokensActiveRequest = null;
    });

    return _updateTokensActiveRequest!;
  }

  Future<Tokens> _updateTokens(refreshToken) async {
    try {
      Tokens refreshedTokens = await openIdApi.refreshTokens(refreshToken);
      tokens = refreshedTokens;
      postRefresh(refreshedTokens);
      return refreshedTokens;
    } on RefreshTokenExpiredException {
      logout();
      rethrow;
    }
  }

  /// Add middleware for process token expiration case
  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest request, {
    num attempt = 0,
  }) async {
    request.headers['Authorization'] = _getAuthString(tokens);
    try {
      final response = await _inner.send(request);
      if (response.statusCode == 401) {
        throw AccessTokenExpiredException();
      }
      return response;
    } on AccessTokenExpiredException {
      if (attempt > 5) {
        throw TooMuchAuthAttemptsException();
      } else {
        tokens = await _tokensUpdated();
        return send(cloneRequest(request), attempt: attempt + 1);
      }
    }
  }

  /// Login methods
  Future<void> loginByPassword({
    required String email,
    required String password,
  }) async {
    tokens = await openIdApi.login(email: email, password: password);
    _postLogin(tokens);
  }

  loginByTokens(Tokens t) async {
    try {
      final refreshedTokens = await _updateTokens(t.refreshToken);
      _postLogin(refreshedTokens);
    } on AuthBackendUnavailableException {
      tokens = t;
      _postLogin(t);
      rethrow;
    }
  }

  _postLogin(Tokens tokens) {
    startRefreshCycle();
    postLogin(tokens);
  }

  logout() {
    clearTokens();
    stopRefreshCycle();
    postLogout();
  }

  /// Refresh cycle allow us update token before 401 error happens
  Timer? preRefresh;
  startRefreshCycle() async {
    stopRefreshCycle();
    // TODO - read duration from token;
    preRefresh = Timer.periodic(const Duration(minutes: 3), (timer) async {
      try {
        await _tokensUpdated();
      } catch (error, stackTrace) {
        if (error is! AuthBackendUnavailableException) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'live_sensors auth client',
              context: ErrorDescription('refreshing OpenID tokens'),
            ),
          );
        }
      }
    });
  }

  stopRefreshCycle() {
    preRefresh?.cancel();
  }
}
