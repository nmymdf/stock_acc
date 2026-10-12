/// 台股漲跌停價計算：前一交易日收盤價 × ±10%，四捨五入到該價格區間的
/// 最小跳動單位。用來判斷「這筆交易是不是用漲停/跌停價成交的」。
library;

/// 股價的最小跳動單位，跟證交所公告的級距一致。
double tickSizeFor(double price) {
  if (price < 10) return 0.01;
  if (price < 50) return 0.05;
  if (price < 100) return 0.1;
  if (price < 500) return 0.5;
  if (price < 1000) return 1;
  return 5;
}

double _roundToTick(double price) {
  final tick = tickSizeFor(price);
  return (price / tick).round() * tick;
}

double limitUpPrice(double prevClose) => _roundToTick(prevClose * 1.1);
double limitDownPrice(double prevClose) => _roundToTick(prevClose * 0.9);

enum LimitStatus { limitUp, limitDown, none }

/// 判斷某個成交價，相對於前一天收盤價，是不是漲停或跌停價（允許極小的
/// 浮點誤差）。
LimitStatus classifyLimitStatus(double tradePrice, double prevClose) {
  if (prevClose <= 0) return LimitStatus.none;
  const epsilon = 0.005;
  if ((tradePrice - limitUpPrice(prevClose)).abs() < epsilon) return LimitStatus.limitUp;
  if ((tradePrice - limitDownPrice(prevClose)).abs() < epsilon) return LimitStatus.limitDown;
  return LimitStatus.none;
}
