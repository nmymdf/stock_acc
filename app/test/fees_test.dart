import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/logic/fees.dart';

void main() {
  group('calcFee', () {
    test('不打折時等於法定費率，低於最低 20 元就用 20 元', () {
      expect(calcFee(1000, 10), 20); // 1000*0.1425% ≈ 1.4 元 → 最低 20
      expect(calcFee(100000, 10), 142); // 100000*0.1425% = 142.5 → 無條件捨去
    });

    test('折扣會照比例打折', () {
      // 犇亞 1.68 折
      expect(calcFee(1000000, 1.68), (1000000 * kFeeRate * 1.68 / 10).floor());
      // 新光 2.8 折
      expect(calcFee(1000000, 2.8), (1000000 * kFeeRate * 2.8 / 10).floor());
    });

    test('折扣算出來比最低手續費低時，用最低手續費', () {
      expect(calcFee(5000, 1.68), 20);
    });
  });

  group('calcTax', () {
    test('買進不收交易稅', () {
      expect(calcTax(false, 100000), 0);
    });

    test('賣出收 0.3%，無條件捨去', () {
      expect(calcTax(true, 100000), 300);
      expect(calcTax(true, 100333), 300);
    });
  });
}
