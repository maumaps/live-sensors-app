import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:live_sensors/logger/log_message.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

class MQTTTransport {
  final port = 1883;
  final mqttEndpoint = 'zigzag.kontur.io';
  final topic = 'live-sensor-logs';
  final maxPendingMessages = 1000;
  late MqttServerClient client;
  final ListQueue<LogMessage> pendingMessages = ListQueue();

  Future init(String clientId) async {
    // Create the client
    client = MqttServerClient.withPort(mqttEndpoint, clientId, port);

    // Setup client
    client.secure = false;
    client.keepAlivePeriod = 20;
    client.setProtocolV311();
    client.logging(on: false);
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;

    final connMess = MqttConnectMessage() //
        .withClientIdentifier(clientId)
        .startClean();

    client.connectionMessage = connMess;

    // Connect the client
    /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
    /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
    /// never send malformed messages.
    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      // Raised by the client when connection fails.
      debugPrint('MQTT::client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      // Raised by the socket layer
      debugPrint('MQTT::socket exception - $e');
      client.disconnect();
    } on Exception catch (e) {
      debugPrint('MQT::unknown exception - $e');
      client.disconnect();
    }
  }

  _onDisconnected() {
    final connectionStatus = client.connectionStatus;
    final isSolicited = connectionStatus?.disconnectionOrigin ==
        MqttDisconnectionOrigin.solicited;

    if (!isSolicited) {
      debugPrint('MQT::INFO - connection lost');
    }
  }

  _onConnected() {
    while (pendingMessages.isNotEmpty) {
      _publish(pendingMessages.removeFirst());
    }
  }

  _queue(LogMessage msg) {
    if (pendingMessages.length >= maxPendingMessages) {
      pendingMessages.removeFirst();
    }
    pendingMessages.add(msg);
  }

  send(LogMessage msg) {
    final isConnected =
        client.connectionStatus?.state == MqttConnectionState.connected;
    if (isConnected) {
      _publish(msg);
    } else {
      _queue(msg);
    }
  }

  _publish(LogMessage msg) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      _queue(msg);
      return;
    }

    /// Use the payload builder rather than a raw buffer
    /// Our known topic to publish to
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(msg));

    /// Publish it
    client.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
  }
}
