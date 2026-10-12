import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/logic/limit_price.dart';

void main() {
  test('跳動單位依價格區間不同', () {
    expect(tickSizeFor(9.5), 0.01);
    expect(tickSizeFor(45), 0.05);
    expect(tickSizeFor(80), 0.1);
    expect(tickSizeFor(300), 0.5);
    expect(tickSizeFor(800), 1);
    expect(tickSizeFor(1200), 5);
  });

  test('漲跌停價 = 前收 ± 10%，四捨五入到跳動單位（台積電範例）', () {
    // 前收 1085，漲停理論價 1193.5，價格已經 >= 1000，跳動單位是 5 -> 1195
    expect(limitUpPrice(1085), 1195);
    // 跌停理論價 976.5，價格 < 1000，跳動單位是 1 -> 977
    expect(limitDownPrice(1085), 977);
  });

  test('classifyLimitStatus 抓得出漲停／跌停／都不是', () {
    expect(classifyLimitStatus(1195, 1085), LimitStatus.limitUp);
    expect(classifyLimitStatus(977, 1085), LimitStatus.limitDown);
    expect(classifyLimitStatus(1100, 1085), LimitStatus.none);
  });

  test('沒有前收資料（0 或負數）一律當作沒有漲跌停資訊，不誤判', () {
    expect(classifyLimitStatus(100, 0), LimitStatus.none);
  });
}
