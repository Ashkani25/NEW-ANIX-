import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/safety/install_id.dart';
import 'package:nexora/core/safety/safety_actions.dart';
import 'package:nexora/worlds/legal/legal_texts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('report helpers', () {
    test('only server account ids are reportable as a user', () {
      expect(reportableUserId('1cb3538a-304a-4bd9-9315-b08b31f3c322'), '1cb3538a-304a-4bd9-9315-b08b31f3c322');
      expect(reportableUserId(' 1CB3538A-304A-4BD9-9315-B08B31F3C322 '), '1cb3538a-304a-4bd9-9315-b08b31f3c322');
      expect(reportableUserId('local-explorer-42'), isNull);
      expect(reportableUserId('bot:2'), isNull);
      expect(reportableUserId(''), isNull);
      expect(reportableUserId(null), isNull);
    });

    test('report reason carries a short excerpt and stays within the server limit', () {
      expect(composeReportReason('spam', null), 'spam');
      expect(composeReportReason('spam', '   '), 'spam');
      expect(composeReportReason('harassment: rude', ' hello '), 'harassment: rude | «hello»');
      final String long = composeReportReason('other', 'x' * 400);
      expect(long, contains('…'));
      expect(long.length, lessThanOrEqualTo(500));
      expect(composeReportReason('o' * 600, null).length, 500);
    });
  });

  group('install id', () {
    test('generated ids match what the server accepts', () {
      final Random r = Random(7);
      for (int i = 0; i < 20; i++) {
        final String id = InstallId.generate(r);
        expect(id.length, 32);
        expect(InstallId.pattern.hasMatch(id), isTrue);
      }
      expect(InstallId.generate(Random(1)), isNot(InstallId.generate(Random(2))));
    });

    test('is created once and kept', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      InstallId.resetCache();
      final String? a = await InstallId.get();
      InstallId.resetCache();
      final String? b = await InstallId.get();
      expect(a, isNotNull);
      expect(a, b);
    });

    test('a malformed stored value is replaced', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'nx.install.id': 'BAD ID'});
      InstallId.resetCache();
      final String? a = await InstallId.get();
      expect(InstallId.pattern.hasMatch(a!), isTrue);
    });
  });

  test('privacy policy explains the ban-evasion hold in both languages', () {
    final String fa = privacyFa.map((LegalSection s) => s.body).join('\n');
    final String en = privacyEn.map((LegalSection s) => s.body).join('\n');
    expect(en, contains('Ban evasion'));
    expect(en, contains('hashes'));
    expect(en, contains('install id'));
    expect(fa, contains('دور زدن مسدودی'));
    expect(fa, contains('هش'));
  });
}
