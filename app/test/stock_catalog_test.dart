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
    expect(searchStocks('美债').map((s) => s.code), contains('00679B'));
    expect(searchStocks(''), isEmpty);
  });

  test('searchStocks 查代號不分大小寫（00679B 打小寫 00679b 也要查得到）', () {
    expect(searchStocks('00679b').map((s) => s.code), contains('00679B'));
    expect(searchStocks('0055').map((s) => s.code), contains('0055'));
  });

  test('債券型 ETF（代號後面帶 B）歸類為上櫃，抓股價才會用對交易所前綴', () {
    // 曾經誤標成「上市」，導致抓即時股價時用錯 tse_ 前綴查不到資料
    // （Yahoo 股市這類代號的網址是 .TWO 結尾，TWO = 上櫃）。
    for (final s in kBuiltinStocks) {
      if (RegExp(r'\d+B$').hasMatch(s.code)) {
        expect(s.market, '上櫃', reason: '${s.code}（${s.name}）應該是上櫃');
      }
    }
  });
}
