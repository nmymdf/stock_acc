/// 手續費、交易稅的計算。跟畫面草稿約定的規則一致：
/// 手續費 = 成交金額 × 0.1425% × 帳戶折扣，最低 20 元；賣出交易稅固定 0.3%。
library;

const double kFeeRate = 0.001425;
const int kMinFee = 20;
const double kTaxRate = 0.003;

/// [discountTenths] 是「N 折」的 N，10 代表不打折，2.8 代表 2.8 折。
int calcFee(double amount, double discountTenths) {
  final fee = amount * kFeeRate * discountTenths / 10;
  return fee.floor() < kMinFee ? kMinFee : fee.floor();
}

int calcTax(bool isSell, double amount) {
  if (!isSell) return 0;
  return (amount * kTaxRate).floor();
}
