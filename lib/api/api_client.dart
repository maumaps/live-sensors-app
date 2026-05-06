import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:live_sensors/app_config.dart';
import 'package:live_sensors/logger/logger.dart';
import 'errors.dart';

class ApiClient {
  final Logger logger = Logger();
  final http.Client _inner;
  final Uri liveSensorEndpoint;

  ApiClient(http.Client httpClient, {Uri? liveSensorEndpoint})
      : _inner = httpClient,
        liveSensorEndpoint = liveSensorEndpoint ?? _configuredEndpoint();

  Future<void> sendSnapshot(Map<String, dynamic> payload) async {
    final response = await _inner.post(
      liveSensorEndpoint,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(payload),
    );

    switch (response.statusCode) {
      case >= 500:
        throw ApiBackendException(response.statusCode.toString());

      case == 400:
        throw BadRequestException();

      case == 401:
      case == 403:
        throw UnauthorizedException(response.statusCode.toString());

      case >= 400:
        throw ApiClientException(response.statusCode.toString());

      case >= 300:
      case >= 200:
      case >= 100:
        break;

      default:
        break;
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to save snapshot. ${response.statusCode}');
    }
  }

  static Uri _configuredEndpoint() {
    if (AppConfig.liveSensorApiUrl.isEmpty) {
      throw StateError(
        'LIVE_SENSORS_API_URL must be provided with --dart-define.',
      );
    }
    return Uri.parse(AppConfig.liveSensorApiUrl);
  }
}
