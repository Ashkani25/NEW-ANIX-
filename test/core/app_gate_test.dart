import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/update/app_gate.dart';

void main() {
  test('force update only below the minimum build; dev builds (vc 0) never blocked', () {
    const AppGateStatus s = AppGateStatus(minVc: 400);
    expect(AppGate.decide(s, 399), AppGateBlock.update);
    expect(AppGate.decide(s, 400), AppGateBlock.none);
    expect(AppGate.decide(s, 0), AppGateBlock.none);
    expect(AppGate.decide(null, 1), AppGateBlock.none, reason: 'offline never blocks');
  });

  test('maintenance blocks everyone except staff bypass; update wins over maintenance', () {
    expect(AppGate.decide(const AppGateStatus(maintenance: true), 500), AppGateBlock.maintenance);
    expect(AppGate.decide(const AppGateStatus(maintenance: true, bypass: true), 500), AppGateBlock.none);
    expect(AppGate.decide(const AppGateStatus(maintenance: true, minVc: 600), 500), AppGateBlock.update);
  });

  test('status parses the server json', () {
    final AppGateStatus s = AppGateStatus.fromJson(<String, dynamic>{
      'min_version_code': 310, 'latest_version_code': 320, 'maintenance': true, 'message_fa': 'الف',
      'message_en': 'a', 'store_url': 'bazaar://details?id=com.nexora.nexora', 'bypass': false,
    });
    expect(s.minVc, 310);
    expect(s.maintenance, isTrue);
    expect(s.storeUrl, startsWith('bazaar://'));
  });
}
