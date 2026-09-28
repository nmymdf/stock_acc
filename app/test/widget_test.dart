// 目前先不做完整的畫面（widget）測試——App 需要本機存檔和連網，測試環境
// 兩者都沒有。核心的計算邏輯（手續費、統計）在 fees_test.dart / stats_test.dart
// 裡有完整的單元測試，之後要加畫面測試也放在這個資料夾。
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('佔位測試：確保測試套件能跑', () => expect(1 + 1, 2));
}
