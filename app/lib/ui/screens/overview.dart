/// 總覽（群體合計）和個人明細兩個畫面。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../logic/stats.dart';
import '../app_version.dart';
import '../format.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/refresh_price_button.dart';
import 'holdings.dart' show buildStockRow;
import 'search.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final shell = context.watch<ShellController>();
    final version = context.watch<AppVersion>();
    final totals = repo.totalsFor(const ScopeFilter.all());

    return Scaffold(
      appBar: AppBar(
        title: const Text('總覽'),
        actions: const [SearchButton(), RefreshPriceButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('作者：ArchieKuo${version.label.isEmpty ? '' : ' · ${version.label}'}',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          HeroTotalsCard(
            label: '全部人合計 · 總市值',
            big: '\$${f0(totals.marketValue)}',
            stats: [
              ('總成本', f0(totals.cost), null),
              ('報酬率（未實現）', pct(totals.unrealized, totals.cost), null),
              ('未實現損益', fp(totals.unrealized), null),
              ('已實現損益', fp(totals.realized), null),
            ],
          ),
          const SizedBox(height: 10),
          const SectionHeader(left: '各人統計', right: '市值'),
          RowList(
            children: [
              for (final p in repo.persons)
                _PersonRow(personId: p.id, selected: shell.stack.isNotEmpty && shell.stack.first is PersonRoute && (shell.stack.first as PersonRoute).personId == p.id),
            ],
          ),
          if (repo.persons.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('還沒有任何人，到「設定」新增一個人開始記帳。'),
            ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final String personId;
  final bool selected;
  const _PersonRow({required this.personId, required this.selected});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final person = repo.personById(personId)!;
    final accounts = repo.accountsOf(personId);
    final s = repo.summarize(ScopeFilter(personId: personId));
    final t = totalsOf(s);
    final pl = t.unrealized + t.realized;
    return InfoRow(
      selected: selected,
      onTap: () => context.read<ShellController>().open(context, PersonRoute(personId)),
      title: Text(person.name),
      subtitle: Text(
          '${accounts.length} 個帳戶 · ${s.where((r) => r.shares > 0).length} 檔持股\n未實現 ${fp(t.unrealized)}　已實現 ${fp(t.realized)}'),
      trailingTop: Text(f0(t.marketValue)),
      trailingBottom: Text(fp(pl), style: TextStyle(color: changeColor(context, pl))),
    );
  }
}

class PersonDetail extends StatelessWidget {
  final String personId;
  const PersonDetail({super.key, required this.personId});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final person = repo.personById(personId);
    if (person == null) {
      return Scaffold(
        appBar: const DetailAppBar(title: Text('個人明細')),
        body: const EmptyHint(text: '這個人已經被刪除了'),
      );
    }
    final personTotals = repo.totalsFor(ScopeFilter(personId: personId));
    final accounts = repo.accountsOf(personId);

    return Scaffold(
      appBar: DetailAppBar(title: Text(person.name), actions: const [RefreshPriceButton()]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          HeroTotalsCard(
            label: '${person.name} · 總市值',
            big: '\$${f0(personTotals.marketValue)}',
            stats: [
              ('總成本', f0(personTotals.cost), null),
              ('報酬率（未實現）', pct(personTotals.unrealized, personTotals.cost), null),
              ('未實現損益', fp(personTotals.unrealized), null),
              ('已實現損益', fp(personTotals.realized), null),
            ],
          ),
          for (final a in accounts) ...[
            SectionHeader(left: '${a.broker} 帳戶 · 手續費 ${a.discount} 折', right: null),
            Builder(builder: (context) {
              final scope = ScopeFilter(accountId: a.id);
              final rows = repo.summarize(scope);
              final t = totalsOf(rows);
              return RowList(
                emptyText: '這個帳戶還沒有任何交易',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Text('市值 ${f0(t.marketValue)}'),
                        const SizedBox(width: 14),
                        Text('未實現 ${fp(t.unrealized)}', style: TextStyle(color: changeColor(context, t.unrealized))),
                        const SizedBox(width: 14),
                        Text('已實現 ${fp(t.realized)}', style: TextStyle(color: changeColor(context, t.realized))),
                      ],
                    ),
                  ),
                  for (final r in rows) buildStockRow(context, r, scope),
                ],
              );
            }),
            const SizedBox(height: 6),
          ],
          if (accounts.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('這個人還沒有券商帳戶，到「設定」新增。')),
        ],
      ),
    );
  }
}
