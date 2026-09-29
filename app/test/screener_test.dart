import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/logic/screener.dart';
import 'package:stock_acc/services/price_service.dart';

ScreenerQuote _q({
  required String code,
  required double price,
  required double prevClose,
  double? open,
  double? high,
  double? low,
  int volumeLots = 0,
}) =>
    ScreenerQuote(
      code: code,
      price: price,
      prevClose: prevClose,
      open: open ?? price,
      high: high ?? price,
      low: low ?? price,
      volumeLots: volumeLots,
    );

void main() {
  test('只保留今天上漲的股票，下跌或平盤的不算候選', () {
    final hits = rankByMomentum([
      _q(code: 'A', price: 110, prevClose: 100),
      _q(code: 'B', price: 100, prevClose: 100),
      _q(code: 'C', price: 90, prevClose: 100),
    ]);
    expect(hits.map((h) => h.code), ['A']);
  });

  test('漲幅大的排前面，量能大、貼近今日高點的分數會加分', () {
    final hits = rankByMomentum([
      _q(code: 'SMALL_RISE', price: 101, prevClose: 100, high: 105, low: 99, volumeLots: 100),
      _q(code: 'BIG_RISE_STRONG', price: 108, prevClose: 100, high: 108, low: 98, volumeLots: 5000),
    ]);
    expect(hits.first.code, 'BIG_RISE_STRONG');
    expect(hits.first.score, greaterThan(hits.last.score));
    expect(hits.first.reasons, isNotEmpty);
  });

  test('貼近今日最高點的理由要出現在 reasons 裡', () {
    final hits = rankByMomentum([
      _q(code: 'NEAR_HIGH', price: 109, prevClose: 100, high: 110, low: 100),
    ]);
    expect(hits.single.reasons.any((r) => r.contains('接近今日最高點')), true);
  });
}
