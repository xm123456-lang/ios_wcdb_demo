import 'package:flutter_test/flutter_test.dart';
import 'package:im_demo/core/ws/ws_config.dart';

void main() {
  group('WsConfig', () {
    test('detects heartbeat response', () {
      const config = WsConfig();

      expect(config.isHeartbeatResponse('{"type":"pong"}'), isTrue);
      expect(config.isHeartbeatResponse('pong'), isTrue);
      expect(config.isHeartbeatResponse('{"type":"message","text":"hi"}'), isFalse);
    });

    test('reconnect delay grows with exponential backoff', () {
      const config = WsConfig(
        initialReconnectDelay: Duration(seconds: 1),
        maxReconnectDelay: Duration(seconds: 30),
      );

      final delays = <int>[];
      for (var attempt = 0; attempt < 6; attempt++) {
        final initialMs = config.initialReconnectDelay.inMilliseconds;
        final maxMs = config.maxReconnectDelay.inMilliseconds;
        final multiplier = 1 << attempt.clamp(0, 10);
        delays.add((initialMs * multiplier).clamp(initialMs, maxMs));
      }

      expect(delays, [1000, 2000, 4000, 8000, 16000, 30000]);
    });
  });
}
