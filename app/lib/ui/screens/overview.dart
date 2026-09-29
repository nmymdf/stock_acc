/// 總覽（群體合計）和個人明細兩個畫面。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../logic/stats.dart';
import '../../app_build_info.dart';
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
    final totals = repo.totalsFor(const ScopeFilter.all());

    return Scaffold(
      appBar: AppBar(
        title: const Text('總覽'),
        actions: const [SearchButton(), RefreshPriceButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('作者：ArchieKuo · $kAppVersion',
                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
              ),
              InkWell(
                onTap: () => _switchGroupDialog(context, repo),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.folder_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text('群體：${repo.activeGroupName}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                    Icon(Icons.arrow_drop_down, size: 16, color: Theme.of(context).colorScheme.primary),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HeroTotalsCard(
            label: '${repo.activeGroupName} · 全部人合計 · 總市值',
            big: '\$${f0(totals.marketValue)}',
            stats: [
              ('總成本', f0(totals.cost), null),
              ('報酬率（未實現）', pct(totals.unrealized, totals.cost), null),
              ('未實現損益', fp(totals.unrealized), null),
              ('已實現損益', fp(totals.realized), null),
            ],
          ),
          const SizedBox(height: 10),
          const SectionHeader(left: '各戶統計', right: '市值'),
          RowList(
            children: [
              for (final p in repo.persons)
                _PersonRow(personId: p.id, selected: shell.stack.isNotEmpty && shell.stack.first is PersonRoute && (shell.stack.first as PersonRoute).personId == p.id),
            ],
          ),
          if (repo.persons.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('還沒有任何戶名，到「設定」新增一個戶名開始記帳。'),
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
          '${accounts.length} 個帳戶 · ${s.where((r) => r.shares > 0).length} 檔持股 · 成本 ${f0(t.cost)}\n未實現 ${fp(t.unrealized)}　已實現 ${fp(t.realized)}'),
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
        appBar: const DetailAppBar(title: Text('戶名明細')),
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
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        Text('成本 ${f0(t.cost)}'),
                        Text('市值 ${f0(t.marketValue)}'),
                        Text('未實現 ${fp(t.unrealized)}', style: TextStyle(color: changeColor(context, t.unrealized))),
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
          if (accounts.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('這個戶名還沒有券商帳戶，到「設定」新增。')),
        ],
      ),
    );
  }
}

/// 群體快速切換：點總覽頁右上角的「群體：xxx」跳出這個清單，選了立刻整個
/// App 切換過去；想管理（改名、刪除）要到設定頁。
Future<void> _switchGroupDialog(BuildContext context, AppRepository repo) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('切換群體'),
      children: [
        for (final g in repo.groups)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, g.id),
            child: Row(children: [
              Icon(
                g.id == repo.activeGroupId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: g.id == repo.activeGroupId ? Theme.of(context).colorScheme.primary : null,
              ),
              const SizedBox(width: 10),
              Text(g.name, style: TextStyle(fontWeight: g.id == repo.activeGroupId ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        const Divider(height: 1),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, '__manage__'),
          child: const Row(children: [
            Icon(Icons.settings_outlined, size: 18, color: Colors.teal),
            SizedBox(width: 10),
            Text('新增／管理群體…', style: TextStyle(color: Colors.teal)),
          ]),
        ),
      ],
    ),
  );
  if (selected == null) return;
  if (selected == '__manage__') {
    if (context.mounted) context.read<ShellController>().switchTab(AppTab.settings);
    return;
  }
  await repo.switchGroup(selected);
}
