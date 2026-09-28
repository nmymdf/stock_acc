import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/logic/stats.dart';
import 'package:stock_acc/models/models.dart';

Trade _t(
  String id,
  String acc,
  String date,
  String code,
  TradeSide side,
  int shares,
  double price, {
  int fee = 0,
  int tax = 0,
}) {
  return Trade(
    id: id,
    accountId: acc,
    date: DateTime.parse(date),
    code: code,
    name: '',
    side: side,
    shares: shares,
    price: price,
    fee: fee,
    tax: tax,
    updatedAt: DateTime.parse(date),
  );
}

void main() {
  group('computeAccountPositions（移動平均成本法）', () {
    test('兩次買進後平均成本、賣出後的已實現損益都正確', () {
      final trades = [
        _t('1', 'acc-a', '2026-01-01', '2330', TradeSide.buy, 1000, 100, fee: 100),
        _t('2', 'acc-a', '2026-01-02', '2330', TradeSide.buy, 1000, 200, fee: 100),
        _t('3', 'acc-a', '2026-01-03', '2330', TradeSide.sell, 1000, 250, fee: 100, tax: 750),
      ];
      final positions = computeAccountPositions(trades);
      expect(positions.length, 1);
      final p = positions.first;
      // 均價 = (100000+100 + 200000+100) / 2000 = 150.1
      expect(p.avgCost, closeTo(150.1, 0.001));
      expect(p.shares, 1000);
      // 賣出所得 250000 - 100(手續費) - 750(稅) - 150100(成本，1000股*150.1) = 99050
      expect(p.realized, closeTo(99050, 0.001));
      expect(p.cost, closeTo(150100, 0.001));
    });

    test('交易的輸入順序不影響結果，只看日期先後', () {
      final inOrder = [
        _t('1', 'a', '2026-01-01', 'X', TradeSide.buy, 100, 10),
        _t('2', 'a', '2026-01-02', 'X', TradeSide.sell, 50, 20),
      ];
      final reversed = inOrder.reversed.toList();
      final p1 = computeAccountPositions(inOrder).first;
      final p2 = computeAccountPositions(reversed).first;
      expect(p1.shares, p2.shares);
      expect(p1.cost, p2.cost);
      expect(p1.realized, p2.realized);
    });

    test('賣出股數不會超過目前持有股數（就算資料有誤也不會變負的）', () {
      final trades = [
        _t('1', 'a', '2026-01-01', 'X', TradeSide.buy, 100, 10),
        _t('2', 'a', '2026-01-02', 'X', TradeSide.sell, 500, 20),
      ];
      final p = computeAccountPositions(trades).first;
      expect(p.shares, 0);
    });

    test('不同帳戶、不同股票分開累計', () {
      final trades = [
        _t('1', 'acc-a', '2026-01-01', '2330', TradeSide.buy, 1000, 100),
        _t('2', 'acc-b', '2026-01-01', '2330', TradeSide.buy, 2000, 200),
        _t('3', 'acc-a', '2026-01-01', '0050', TradeSide.buy, 500, 50),
      ];
      final positions = computeAccountPositions(trades);
      expect(positions.length, 3);
    });
  });

  group('summarizeByCode / totalsOf', () {
    test('同一支股票跨帳戶會加總，市值和未實現損益跟著現價變動', () {
      final positions = [
        AccountPosition(accountId: 'a', code: '2330', shares: 1000, cost: 100000),
        AccountPosition(accountId: 'b', code: '2330', shares: 500, cost: 60000),
      ];
      final rows = summarizeByCode(positions, {'2330': 120});
      expect(rows.length, 1);
      final r = rows.first;
      expect(r.shares, 1500);
      expect(r.cost, 160000);
      expect(r.marketValue, 1500 * 120);
      expect(r.unrealized, 1500 * 120 - 160000);
    });

    test('沒有現價時市值和未實現損益是 null，不會影響合計裡的已實現損益', () {
      final positions = [
        AccountPosition(accountId: 'a', code: 'X', shares: 100, cost: 1000, realized: 500),
      ];
      final rows = summarizeByCode(positions, {});
      expect(rows.first.marketValue, isNull);
      expect(rows.first.unrealized, isNull);
      final totals = totalsOf(rows);
      expect(totals.marketValue, 0);
      expect(totals.realized, 500);
    });

    test('已出清（股數為 0）的股票也算已實現損益', () {
      final positions = [
        AccountPosition(accountId: 'a', code: 'X', shares: 0, cost: 0, realized: 1234),
      ];
      final rows = summarizeByCode(positions, {'X': 99});
      expect(rows.first.isClosed, true);
      expect(rows.first.marketValue, 0);
    });
  });
}
