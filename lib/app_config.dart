class AppConfig {
  static const liveSensorApiUrl = String.fromEnvironment(
    'LIVE_SENSORS_API_URL',
  );
  static const openIdTokenUrl = String.fromEnvironment(
    'LIVE_SENSORS_OPENID_TOKEN_URL',
  );
  static const openIdClientId = String.fromEnvironment(
    'LIVE_SENSORS_OPENID_CLIENT_ID',
  );
  static const mqttLogsEnabled = bool.fromEnvironment(
    'LIVE_SENSORS_MQTT_LOGS_ENABLED',
  );
  static const mqttEndpoint = String.fromEnvironment(
    'LIVE_SENSORS_MQTT_ENDPOINT',
  );
  static const mqttPort = int.fromEnvironment(
    'LIVE_SENSORS_MQTT_PORT',
    defaultValue: 8883,
  );
  static const mqttTopic = String.fromEnvironment(
    'LIVE_SENSORS_MQTT_TOPIC',
    defaultValue: 'live-sensor-logs',
  );
}
