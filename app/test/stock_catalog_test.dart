import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/data/stock_catalog.dart';

void main() {
  test('內建清單裡沒有重複的代號（避免手動維護時複製貼上打架）', () {
    final codes = kBuiltinStocks.map((s) => s.code).toList();
    expect(codes.length, codes.toSet().length);
  });

  test('查得到使用者常問的幾支代號（0055、00679B 等）', () {
    for (final code in ['0050', '0055', '00679B', '2330', '00919']) {
      expect(kBuiltinStocksByCode.containsKey(code), true, reason: '找不到 $code');
    }
  });

  test('searchStocks 用代號開頭或名稱關鍵字都查得到', () {
    expect(searchStocks('00679').map((s) => s.code), contains('00679B'));
    expect(searchStocks('美債').map((s) => s.code), contains('00679B'));
    expect(searchStocks(''), isEmpty);
  });

  test('searchStocks 查代號不分大小寫（00679B 打小寫 00679b 也要查得到）', () {
    expect(searchStocks('00679b').map((s) => s.code), contains('00679B'));
    expect(searchStocks('0055').map((s) => s.code), contains('0055'));
  });

  test('債券型 ETF 的市場別（上市／上櫃）要跟官方資料一致，抓股價才會用對交易所前綴', () {
    // 曾經誤以為代號後面帶 B 的債券型 ETF 全部都是上櫃，其實是逐檔不同
    // （00710B、00711B、00775B 是上市），不能用代號規則一律判斷。
    expect(kBuiltinStocksByCode['00679B']?.market, '上櫃');
    expect(kBuiltinStocksByCode['00710B']?.market, '上市');
    expect(kBuiltinStocksByCode['00775B']?.market, '上市');
  });
}
