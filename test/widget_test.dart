import 'package:flutter_test/flutter_test.dart';
import 'package:im_demo/core/ws/ws_client.dart';
import 'package:im_demo/core/ws/ws_status.dart';
import 'package:im_demo/main.dart';

void main() {
  testWidgets('App starts at connect page', (WidgetTester tester) async {
    await tester.pumpWidget(const ImApp());
    expect(find.text('连接 IM'), findsOneWidget);
  });

  test('WsClient is singleton', () {
    expect(identical(WsClient.instance, WsClient.instance), isTrue);
    expect(WsClient.instance.status, WsStatus.disconnected);
  });
}
