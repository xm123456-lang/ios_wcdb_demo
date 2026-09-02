import 'package:connectivity_plus/connectivity_plus.dart';

/// 判断当前是否有可用网络。
bool networkIsOnline(List<ConnectivityResult> results) {
  return results.any((result) => result != ConnectivityResult.none);
}
