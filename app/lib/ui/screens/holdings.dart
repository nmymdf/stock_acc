/// 持股列表和個股明細。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../logic/stats.dart';
import '../format.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/refresh_price_button.dart';
import 'search.dart';
import 'trades.dart' show buildTradeRow;
import 'info.dart' show NewsPreview;

/// 股票列表的一列，總覽個人頁、持股頁、個股「誰持有」都共用這個樣式。
Widget buildStockRow(BuildContext context, StockSummary r, ScopeFilter scope, {bool nested = false}) {
  final repo = context.watch<AppRepository>();
  final q = repo.quoteOf(r.code);
  final pl = r.isClosed ? r.realized : (r.unrealized ?? 0);
  return InfoRow(
    onTap: () => context.read<ShellController>().open(
          context,
          StockRoute(r.code, scope: scope),
          nested: nested,
        ),
    title: Text('${r.code}  ${repo.nameOf(r.code)}'),
    subtitle: Text(r.isClosed
        ? '已出清'
        : '${shareTxt(r.shares)} · 均價 ${f2(r.avgCost)}'),
    trailingTop: q == null
        ? const Text('—')
        : Text.rich(TextSpan(children: [
            TextSpan(text: '${f2(q.price)} '),
            TextSpan(
              text: q.change == 0 ? '' : (q.change > 0 ? '▲${f2(q.change.abs())}' : '▼${f2(q.change.abs())}'),
              style: TextStyle(color: changeColor(context, q.change), fontSize: 12),
            ),
          ])),
    trailingBottom: Text(
      r.isClosed ? '已實現 ${fp(pl)}' : '${fp(pl)} (${pct(pl, r.cost)})',
      style: TextStyle(color: changeColor(context, pl)),
    ),
  );
}

class HoldingsScreen extends StatefulWidget {
  const HoldingsScreen({super.key});

  @override
  State<HoldingsScreen> createState() => _HoldingsScreenState();
}

class _HoldingsScreenState extends State<HoldingsScreen> {
  String? _personId;
  String? _accountId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final scope = ScopeFilter(personId: _personId, accountId: _accountId);
    final rows = repo.summarize(scope);
    final held = rows.where((r) => r.shares > 0).toList();
    final closed = rows.where((r) => r.shares == 0).toList();
    final totals = totalsOf(rows);
    final accountsForPerson = _personId == null ? repo.data.accounts : repo.accountsOf(_personId!);

    return Scaffold(
      appBar: AppBar(title: const Text('持股'), actions: const [SearchButton(), RefreshPriceButton()]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _personId,
                decoration: const InputDecoration(labelText: '人'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  for (final p in repo.persons) DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() {
                  _personId = v;
                  _accountId = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: '帳戶'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  for (final a in accountsForPerson)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(_personId == null ? '${repo.personById(a.personId)?.name}-${a.broker}' : a.broker),
                    ),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          StatGrid(columns: 3, stats: [
            ('市值', f0(totals.marketValue), null),
            ('未實現', fp(totals.unrealized), changeColor(context, totals.unrealized)),
            ('已實現', fp(totals.realized), changeColor(context, totals.realized)),
          ]),
          SectionHeader(left: '持有中 ${held.length} 檔 · 點股票看交易明細', right: '現價 / 損益'),
          RowList(children: [for (final r in held) buildStockRow(context, r, scope)], emptyText: '沒有持股'),
          if (closed.isNotEmpty) ...[
            const SectionHeader(left: '已出清'),
            RowList(children: [for (final r in closed) buildStockRow(context, r, scope)]),
          ],
        ],
      ),
    );
  }
}

class StockDetail extends StatelessWidget {
  final String code;
  final ScopeFilter scope;
  const StockDetail({super.key, required this.code, required this.scope});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final rows = repo.summarize(scope);
    final s = rows.where((r) => r.code == code).firstOrNull;
    final q = repo.quoteOf(code);
    final positions = repo.positionsForCode(code, scope: scope);
    final trades = repo.trades.where((t) => t.code == code && positions.any((p) => p.accountId == t.accountId)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final watching = repo.isWatching(code);

    return Scaffold(
      appBar: DetailAppBar(
        title: Text('$code ${repo.nameOf(code)}'),
        actions: [
          IconButton(
            icon: Icon(watching ? Icons.star : Icons.star_border),
            tooltip: watching ? '已關注' : '加入關注',
            onPressed: () => repo.toggleWatch(code),
          ),
          const RefreshPriceButton(label: '更新'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${repo.marketOf(code)} · 現價', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  q == null
                      ? const Text('尚無現價，按「更新」抓取')
                      : Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text(f2(q.price), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(
                            '${q.change > 0 ? '▲' : q.change < 0 ? '▼' : ''}${f2(q.change.abs())} (${pct(q.change, q.price - q.change)})',
                            style: TextStyle(color: changeColor(context, q.change)),
                          ),
                        ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (s != null) ...[
            StatGrid(columns: 3, stats: [
              ('總股數', f0(s.shares), null),
              ('均價', f2(s.avgCost), null),
              ('成本', f0(s.cost), null),
              ('市值', f0(s.marketValue ?? 0), null),
              ('未實現', fp(s.unrealized ?? 0), changeColor(context, s.unrealized ?? 0)),
              ('已實現', fp(s.realized), changeColor(context, s.realized)),
            ]),
            const SectionHeader(left: '誰持有（依帳戶）', right: '損益'),
            RowList(children: [
              for (final p in positions)
                Builder(builder: (context) {
                  final acc = repo.accountById(p.accountId);
                  final person = acc == null ? null : repo.personById(acc.personId);
                  final un = q == null || p.shares == 0 ? 0.0 : p.shares * q.price - p.cost;
                  final pl = un + p.realized;
                  return InfoRow(
                    title: Text('${person?.name ?? '（已刪除）'}'),
                    subtitle: Text(acc?.broker ?? ''),
                    trailingTop: Text(fp(pl), style: TextStyle(color: changeColor(context, pl))),
                    trailingBottom: Text(p.shares > 0 ? '${shareTxt(p.shares)} · 均價 ${f2(p.avgCost)}' : '已出清'),
                  );
                }),
            ]),
            SectionHeader(left: '交易明細 ${trades.length} 筆（點一下可修改）'),
            RowList(children: [for (final t in trades) buildTradeRow(context, t, nested: true)], emptyText: '沒有交易'),
          ] else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('這個範圍內還沒有這支股票的交易。'),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => context.read<ShellController>().open(
                        context,
                        TradeFormRoute(presetCode: code),
                        nested: true,
                      ),
                  child: Text('＋ 新增 ${repo.nameOf(code)} 的交易'),
                ),
              ]),
            ),
          const SizedBox(height: 6),
          NewsPreview(code: code),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
