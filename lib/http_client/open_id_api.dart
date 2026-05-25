import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:live_sensors/entities/tokens.dart';

import 'errors.dart';

class OpenIdApi {
  final Uri refreshPath;
  final String clientId;
  final http.Client _client;

  OpenIdApi({
    required this.refreshPath,
    required this.clientId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<Tokens> login({
    required String email,
    required String password,
  }) async {
    final response = await _postTokenRequest({
      'username': email,
      'password': password,
      'client_id': clientId,
      'grant_type': 'password',
    });

    final statusType = (response.statusCode / 100).floor() * 100;
    switch (statusType) {
      case 200:
        return _parseTokens(response.body);
      case 400:
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw BadCredentialsException(
          json['error_description']?.toString() ?? 'Unknown error',
        );
      case 300:
      case 500:
      default:
        throw const AuthBackendUnavailableException();
    }
  }

  Future<Tokens> refreshTokens(String refreshToken) async {
    final response = await _postTokenRequest({
      'client_id': clientId,
      'refresh_token': refreshToken,
      'grant_type': 'refresh_token',
    });

    final statusType = (response.statusCode / 100).floor() * 100;
    switch (statusType) {
      case 200:
        return _parseTokens(response.body);
      case 400:
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'];
        final description =
            json['error_description']?.toString() ?? 'Refresh failed';
        if (error == 'invalid_grant') {
          throw RefreshTokenExpiredException(description);
        }
        throw AuthBackendUnavailableException(description);
      case 300:
      case 500:
      default:
        throw const AuthBackendUnavailableException(
          'Error contacting the authentication server',
        );
    }
  }

  Future<http.Response> _postTokenRequest(Map<String, String> body) async {
    try {
      return await _client.post(refreshPath, body: body);
    } on SocketException catch (e) {
      throw AuthBackendUnavailableException(e.message);
    } on http.ClientException catch (e) {
      throw AuthBackendUnavailableException(e.message);
    }
  }

  Tokens _parseTokens(String responseBody) {
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return Tokens(
      sessionId: json['session_state'] as String,
      expiresIn: json['expires_in'] as int,
      refreshExpiresIn: json['refresh_expires_in'] as int,
      refreshToken: json['refresh_token'] as String,
      accessToken: json['access_token'] as String,
    );
  }
}
