import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/push/push_service.dart';

void main() {
  test('push is off unless the build carries the flag and every Firebase option', () {
    expect(PushService.configured, isFalse); // CI / default builds
    expect(PushService.isConfigured(flag: true, apiKey: 'k', appId: 'a', senderId: 's', projectId: 'p'), isTrue);
    expect(PushService.isConfigured(flag: false, apiKey: 'k', appId: 'a', senderId: 's', projectId: 'p'), isFalse);
    expect(PushService.isConfigured(flag: true, apiKey: '', appId: 'a', senderId: 's', projectId: 'p'), isFalse);
    expect(PushService.isConfigured(flag: true, apiKey: 'k', appId: 'a', senderId: 's', projectId: ''), isFalse);
  });

  test('a push tap only opens in-app routes', () {
    expect(PushService.routeOf(<String, dynamic>{'route': '/tournaments/abc'}), '/tournaments/abc');
    expect(PushService.routeOf(<String, dynamic>{'route': '/online/pool8?code=AB12'}), '/online/pool8?code=AB12');
    expect(PushService.routeOf(<String, dynamic>{'route': 'https://evil.example'}), isNull);
    expect(PushService.routeOf(<String, dynamic>{'route': '//evil.example'}), isNull);
    expect(PushService.routeOf(<String, dynamic>{}), isNull);
  });

  test('push-send channel ids exist on the device', () {
    expect(PushService.channels.map((c) => c.id), containsAll(<String>['messages', 'calls', 'matches', 'social', 'general']));
  });
}
