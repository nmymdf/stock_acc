/// 數字、股數的顯示格式，跟畫面草稿的規則一致：
/// 千分位、正數加「+」、1000 股顯示成「1 張」。
library;

import 'package:intl/intl.dart';

final _int = NumberFormat.decimalPattern('zh_TW');
final _dec2 = NumberFormat('#,##0.00', 'zh_TW');

String f0(num n) => _int.format(n.round());
String f2(num n) => _dec2.format(n);

/// 加正負號的整數，例如損益 +12,345 / -8,000。
String fp(num n) => (n > 0 ? '+' : '') + f0(n);

String pct(num a, num b) {
  if (b == 0) return '—';
  final v = a / b * 100;
  return (v > 0 ? '+' : '') + v.toStringAsFixed(2) + '%';
}

/// 1000 股的倍數顯示成「N 張」，否則顯示「N 股」。
String shareTxt(int shares) {
  if (shares % 1000 == 0) return '${shares ~/ 1000} 張';
  return '${f0(shares)} 股';
}

String monthLabel(String ym) {
  final parts = ym.split('-');
  if (parts.length != 2) return ym;
  return '${parts[0]} 年 ${parts[1]} 月';
}
