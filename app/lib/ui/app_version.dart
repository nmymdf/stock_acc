/// 讀這次安裝的版本號（pubspec.yaml 的 version），顯示在總覽頁作者名字旁邊。
/// 每次確認 App 有沒有更新到最新版，看這個數字就知道，不用用猜的。
library;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersion extends ChangeNotifier {
  String label = '';

  Future<void> load() async {
    final info = await PackageInfo.fromPlatform();
    label = 'v${info.version}+${info.buildNumber}';
    notifyListeners();
  }
}
