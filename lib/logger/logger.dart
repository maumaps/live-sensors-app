import 'dart:async';
import 'log_message.dart';
import 'transport.dart';

class Logger {
  // 10_000 must be enough for write logs 8 hours every 3 second
  int historyLength = 1000;
  final client = MQTTTransport();

  // Singleton
  static final Logger _singleton = Logger._internal();
  factory Logger() => _singleton;
  Logger._internal();

  Future<void> init() async {
    await client.init('live_sensors_app');
  }

  final List<LogMessage> _records = <LogMessage>[];
  final List<void Function(List<LogMessage>)> _listeners =
      <void Function(List<LogMessage>)>[];

  void _add(LogMessage record) {
    if (_records.length > historyLength) {
      _records.removeAt(0);
    }
    client.send(record);
    _records.add(record);
    _update();
  }

  void _update() {
    for (final listener in _listeners) {
      listener(_records);
    }
  }

  void info(String msg) {
    _add(LogMessage(level: LogLevel.info, message: msg));
  }

  void warn(String msg) {
    _add(LogMessage(level: LogLevel.warning, message: msg));
  }

  void error(String msg) {
    _add(LogMessage(level: LogLevel.error, message: msg));
  }

  void Function() subscribe(void Function(List<LogMessage>) listener) {
    _listeners.add(listener);
    Future(() => listener(_records));
    return () {
      _listeners.remove(listener);
    };
  }
}
