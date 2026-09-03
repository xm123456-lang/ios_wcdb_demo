import 'package:flutter/material.dart';
import 'package:im_demo/core/http/http_client.dart';
import 'package:im_demo/im/im_service.dart';
import 'package:im_demo/ui/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ImService.instance.init();
  runApp(const ImApp());
}

Future<void> loginIM() async {
  HttpClient.instance.setToken('your-token');
  final res = await HttpClient.instance.get('12312');
  if (res.success) {
    // use res.data
  }
}

class ImApp extends StatelessWidget {
  const ImApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IM Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
