import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:live_sensors/app_config.dart';
import 'package:live_sensors/logger/log_message.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTTransport {
  final port = AppConfig.mqttPort;
  final mqttEndpoint = AppConfig.mqttEndpoint;
  final topic = AppConfig.mqttTopic;
  final maxPendingMessages = 1000;
  MqttServerClient? client;
  final ListQueue<LogMessage> pendingMessages = ListQueue();

  Future<void> init(String clientId) async {
    if (!AppConfig.mqttLogsEnabled || mqttEndpoint.isEmpty) {
      return;
    }

    // Create the client
    final mqttClient = MqttServerClient.withPort(mqttEndpoint, clientId, port);
    client = mqttClient;

    // Setup client
    mqttClient.secure = true;
    mqttClient.keepAlivePeriod = 20;
    mqttClient.setProtocolV311();
    mqttClient.logging(on: false);
    mqttClient.onDisconnected = _onDisconnected;
    mqttClient.onConnected = _onConnected;

    final connMess = MqttConnectMessage() //
        .withClientIdentifier(clientId)
        .startClean();

    mqttClient.connectionMessage = connMess;

    // Connect the client
    /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
    /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
    /// never send malformed messages.
    try {
      await mqttClient.connect();
    } on NoConnectionException catch (e) {
      // Raised by the client when connection fails.
      debugPrint('MQTT::client exception - $e');
      mqttClient.disconnect();
    } on SocketException catch (e) {
      // Raised by the socket layer
      debugPrint('MQTT::socket exception - $e');
      mqttClient.disconnect();
    } on Exception catch (e) {
      debugPrint('MQT::unknown exception - $e');
      mqttClient.disconnect();
    }
  }

  void _onDisconnected() {
    final connectionStatus = client?.connectionStatus;
    final isSolicited = connectionStatus?.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited;

    if (!isSolicited) {
      debugPrint('MQT::INFO - connection lost');
    }
  }

  void _onConnected() {
    while (pendingMessages.isNotEmpty) {
      _publish(pendingMessages.removeFirst());
    }
  }

  void _queue(LogMessage msg) {
    if (pendingMessages.length >= maxPendingMessages) {
      pendingMessages.removeFirst();
    }
    pendingMessages.add(msg);
  }

  void send(LogMessage msg) {
    final isConnected =
        client?.connectionStatus?.state == MqttConnectionState.connected;
    if (isConnected) {
      _publish(msg);
    } else {
      _queue(msg);
    }
  }

  void _publish(LogMessage msg) {
    final mqttClient = client;
    if (mqttClient?.connectionStatus?.state != MqttConnectionState.connected) {
      _queue(msg);
      return;
    }

    /// Use the payload builder rather than a raw buffer
    /// Our known topic to publish to
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(msg));

    /// Publish it
    mqttClient!.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
  }
}
