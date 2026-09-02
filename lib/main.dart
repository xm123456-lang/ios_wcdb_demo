import 'package:flutter/material.dart';
import 'package:im_demo/im/im_service.dart';
import 'package:im_demo/ui/connect_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ImService.instance.init();
  runApp(const ImApp());
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
      home: const ConnectPage(),
    );
  }
}
