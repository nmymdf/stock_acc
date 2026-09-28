/// 查詢股票：輸入代號或名稱找股票，可以直接看個股，或加入關注清單。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../data/stock_catalog.dart';
import '../format.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SearchButton extends StatelessWidget {
  final bool forWatch;
  const SearchButton({super.key, this.forWatch = false});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.read<ShellController>().open(context, SearchRoute(forWatch: forWatch)),
      icon: const Icon(Icons.search, size: 18),
      label: Text(forWatch ? '＋ 加入' : '查詢'),
    );
  }
}

class SearchDetail extends StatefulWidget {
  final bool forWatch;
  const SearchDetail({super.key, this.forWatch = false});

  @override
  State<SearchDetail> createState() => _SearchDetailState();
}

class _SearchDetailState extends State<SearchDetail> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final query = _ctrl.text.trim();
    final hits = query.isEmpty ? const <StockInfo>[] : searchStocks(query);
    final recent = query.isEmpty
        ? repo.heldCodes.take(5).map((c) => kBuiltinStocksByCode[c]).whereType<StockInfo>().toList()
        : const <StockInfo>[];

    Widget row(StockInfo s) {
      final q = repo.quoteOf(s.code);
      final watching = repo.isWatching(s.code);
      return InfoRow(
        title: Text('${s.code}  ${s.name}${watching ? '  ★' : ''}'),
        subtitle: Text(s.market),
        trailingTop: q == null
            ? const Text('—')
            : Text.rich(TextSpan(children: [
                TextSpan(text: '${f2(q.price)} '),
                TextSpan(
                  text: q.change == 0 ? '' : (q.change > 0 ? '▲${f2(q.change.abs())}' : '▼${f2(q.change.abs())}'),
                  style: TextStyle(color: changeColor(context, q.change), fontSize: 12),
                ),
              ])),
        onTap: () async {
          if (widget.forWatch) {
            await repo.toggleWatch(s.code);
            if (context.mounted) {
              context.read<ShellController>().closeDetail();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已加入關注：${s.name}')),
              );
            }
          } else {
            context.read<ShellController>().open(context, StockRoute(s.code));
          }
        },
      );
    }

    return Scaffold(
      appBar: DetailAppBar(title: Text(widget.forWatch ? '加入關注' : '查詢股票')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: '輸入代號或名稱', hintText: '例如 2330 或 台積'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (query.isNotEmpty) ...[
            SectionHeader(left: '搜尋結果 ${hits.length} 筆'),
            RowList(children: [for (final s in hits) row(s)], emptyText: '找不到符合的股票'),
          ] else ...[
            const SectionHeader(left: '目前持有'),
            RowList(children: [for (final s in recent) row(s)], emptyText: '輸入代號或名稱開始查詢'),
          ],
        ],
      ),
    );
  }
}
