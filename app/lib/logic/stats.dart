/// 股票統計：用「移動平均成本法」計算持股、成本、已實現／未實現損益。
///
/// 跟畫面草稿（stats.js／stock-app-mock.html 的 computeStats）用同一套算法：
/// 每次買進後重新平均成本；賣出不影響剩餘股數的均價，賣出的損益 = 賣出所得
/// （含手續費、交易稅）－用均價算出的成本。
library;

import '../models/models.dart';

/// 一個「券商帳戶 × 股票代號」的持倉狀態，是統計的最小單位。
/// 個人、群體的合計都是把多個 [AccountPosition] 加總而成。
class AccountPosition {
  final String accountId;
  final String code;
  int shares;
  double cost;
  double realized;

  AccountPosition({
    required this.accountId,
    required this.code,
    this.shares = 0,
    this.cost = 0,
    this.realized = 0,
  });

  double get avgCost => shares == 0 ? 0 : cost / shares;
}

/// 依帳戶＋代號分組，用移動平均成本法把交易「播放」一遍，算出每一組的狀態。
/// 交易依日期（同一天再依 id）排序，跟輸入順序無關。
List<AccountPosition> computeAccountPositions(Iterable<Trade> trades) {
  final sorted = trades.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });

  final map = <String, AccountPosition>{};
  for (final t in sorted) {
    final key = '${t.accountId}|${t.code}';
    final p = map.putIfAbsent(
      key,
      () => AccountPosition(accountId: t.accountId, code: t.code),
    );
    final amount = t.amount;
    if (t.side == TradeSide.buy) {
      p.shares += t.shares;
      p.cost += amount + t.fee;
    } else {
      final sold = t.shares > p.shares ? p.shares : t.shares;
      final costOut = p.shares == 0 ? 0.0 : p.avgCost * sold;
      p.realized += amount - t.fee - t.tax - costOut;
      p.shares -= sold;
      p.cost -= costOut;
      if (p.shares == 0) p.cost = 0;
    }
  }
  return map.values.toList();
}

/// 一支股票彙總後的統計（可能是某個帳戶、某個人，或全部人合計）。
class StockSummary {
  final String code;
  final int shares;
  final double cost;
  final double realized;
  final double? price;

  StockSummary({
    required this.code,
    required this.shares,
    required this.cost,
    required this.realized,
    this.price,
  });

  double get avgCost => shares == 0 ? 0 : cost / shares;
  double? get marketValue => price == null ? null : shares * price!;
  double? get unrealized => price == null ? null : marketValue! - cost;

  /// 是否已經出清（曾經有交易，現在股數為 0）。
  bool get isClosed => shares == 0;
}

/// 把一批 [AccountPosition]（已經用 [accountFilter] 篩過）依代號加總。
/// [prices] 沒有這支股票的現價時，市值和未實現損益會是 null。
List<StockSummary> summarizeByCode(
  Iterable<AccountPosition> positions,
  Map<String, double> prices,
) {
  final byCode = <String, ({int shares, double cost, double realized})>{};
  for (final p in positions) {
    final cur = byCode[p.code] ?? (shares: 0, cost: 0.0, realized: 0.0);
    byCode[p.code] = (
      shares: cur.shares + p.shares,
      cost: cur.cost + p.cost,
      realized: cur.realized + p.realized,
    );
  }
  return byCode.entries
      .map((e) => StockSummary(
            code: e.key,
            shares: e.value.shares,
            cost: e.value.cost,
            realized: e.value.realized,
            price: prices[e.key],
          ))
      .toList();
}

/// 一組股票統計的合計數字，用於總覽、持股頁最上面的彙總卡片。
class Totals {
  final double cost;
  final double marketValue;
  final double unrealized;
  final double realized;

  const Totals({
    this.cost = 0,
    this.marketValue = 0,
    this.unrealized = 0,
    this.realized = 0,
  });

  Totals operator +(Totals o) => Totals(
        cost: cost + o.cost,
        marketValue: marketValue + o.marketValue,
        unrealized: unrealized + o.unrealized,
        realized: realized + o.realized,
      );

  /// 有現價才算得出報酬率；沒有市值的股票（尚無現價）不計入分母。
  double get returnRate => cost == 0 ? 0 : unrealized / cost;
}

Totals totalsOf(Iterable<StockSummary> rows) => rows.fold(
      const Totals(),
      (t, r) => t +
          Totals(
            cost: r.cost,
            marketValue: r.marketValue ?? 0,
            unrealized: r.unrealized ?? 0,
            realized: r.realized,
          ),
    );
