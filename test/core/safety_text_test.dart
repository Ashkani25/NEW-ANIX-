import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/safety/safety_actions.dart';

void main() {
  test('server safety errors map to readable text in both languages', () {
    expect(safetyErrorText('PostgrestException(message: blocked, code: P0001)', true), contains('مسدود'));
    expect(safetyErrorText('banned', false), contains('banned'));
    expect(safetyErrorText('username_reserved', false), contains('reserved'));
    expect(safetyErrorText('name_profane', true), isNotNull);
    expect(safetyErrorText('room full', false), isNull);
  });
}
