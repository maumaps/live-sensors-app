import 'package:flutter_test/flutter_test.dart';
import 'package:live_sensors/entities/session.dart';

void main() {
  test('Session.fromJson accepts an empty stored session', () {
    final session = Session.fromJson({'tokens': null});

    expect(
      session.tokens,
      isNull,
      reason: 'Logout and first-run storage may contain a token-free session.',
    );
  });
}
