import 'package:im_demo/core/http/http_client.dart';
import 'package:im_demo/core/ws/ws_client.dart';

class ImAdapter {
  static void connectWS(String token) async {
    try {
      final res = await HttpClient.instance.get("/app/v1/users/ws");
      final host = res.data["data"]["host"];
      WsClient.instance.connect(host);
    } catch (e) {}
  }
}
