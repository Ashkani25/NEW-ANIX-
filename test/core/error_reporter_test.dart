import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/diagnostics/error_reporter.dart';

void main() {
  test('client-side limits: dedupe within 10 min, at most 6 per minute', () {
    final ErrorReporter r = ErrorReporter.instance;
    final DateTime t = DateTime(2026, 1, 1, 12);
    expect(r.admit('a', t), isTrue);
    expect(r.admit('a', t.add(const Duration(minutes: 5))), isFalse, reason: 'same error again too soon');
    int ok = 0;
    for (int i = 0; i < 10; i++) {
      if (r.admit('b$i', t.add(const Duration(seconds: 1)))) ok++;
    }
    expect(ok, 5, reason: '6 per minute including the first');
    expect(r.admit('a', t.add(const Duration(minutes: 11))), isTrue, reason: 'after the dedupe window, new minute');
  });
}
