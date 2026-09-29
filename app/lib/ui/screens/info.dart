/// 資訊分頁：目前只有「新聞」，之後會在同一排子分頁加指標、法人、股利。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repository.dart';
import '../../data/stock_catalog.dart';
import '../../logic/screener.dart';
import '../../services/news_cache.dart';
import '../../services/news_service.dart';
import '../../services/price_service.dart';
import '../format.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'search.dart';

const _kDaysOptions = {'今天': 1, '3 天': 3, '7 天': 7};

enum _InfoSubTab { news, screener }

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  String _days = '7 天';
  bool _refreshing = false;
  _InfoSubTab _subTab = _InfoSubTab.news;

  Future<void> _refresh(AppRepository repo, NewsCache cache) async {
    final codes = {...repo.heldCodes, ...repo.watchlist}.toList();
    if (codes.isEmpty) return;
    setState(() => _refreshing = true);
    await cache.refreshAll(codes, {for (final c in codes) c: repo.nameOf(c)}, days: _kDaysOptions[_days]!);
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final cache = context.watch<NewsCache>();
    final held = repo.heldCodes;
    final watch = repo.watchlist.where((c) => !held.contains(c)).toList();

    Widget row(String code) {
      final items = cache.itemsFor(code);
      final n = items == null ? null : clusterNewsCount(items, merge: repo.mergeNews);
      final sources = items == null ? const <String>[] : {for (final i in items) i.source}.toList();
      final srcText = items == null
          ? (cache.isLoading(code) ? '抓取中…' : '尚未更新，按上方「更新」')
          : (sources.isEmpty ? '沒有新聞' : (sources.length > 2 ? '${sources.take(2).join('、')} 等 ${sources.length} 家' : sources.join('、')));
      return InfoRow(
        onTap: () => context.read<ShellController>().open(context, NewsListRoute(code)),
        title: Text('$code  ${repo.nameOf(code)}'),
        subtitle: Text(srcText),
        trailingTop: n == null ? const Text('—') : Text('$n 則'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('資訊'),
        actions: [
          if (_subTab == _InfoSubTab.news)
            TextButton.icon(
              onPressed: _refreshing ? null : () => _refresh(repo, cache),
              icon: _refreshing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('更新'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(
              child: _subTab == _InfoSubTab.news
                  ? FilledButton.tonal(onPressed: null, child: const Text('新聞'))
                  : TextButton(
                      onPressed: () => setState(() => _subTab = _InfoSubTab.news),
                      child: const Text('新聞', style: TextStyle(color: Colors.grey)),
                    ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _subTab == _InfoSubTab.screener
                  ? FilledButton.tonal(onPressed: null, child: const Text('選股雷達'))
                  : TextButton(
                      onPressed: () => setState(() => _subTab = _InfoSubTab.screener),
                      child: const Text('選股雷達', style: TextStyle(color: Colors.grey)),
                    ),
            ),
            const SizedBox(width: 6),
            for (final t in ['法人', '股利'])
              Expanded(
                child: TextButton(
                  onPressed: () => ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('「$t」之後再做'))),
                  child: Text(t, style: const TextStyle(color: Colors.grey)),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          if (_subTab == _InfoSubTab.news) ...[
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _days,
                  decoration: const InputDecoration(labelText: '期間'),
                  items: [for (final d in _kDaysOptions.keys) DropdownMenuItem(value: d, child: Text(d))],
                  onChanged: (v) => setState(() => _days = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('合併相同新聞', style: TextStyle(fontSize: 13)),
                  value: repo.mergeNews,
                  onChanged: (v) => repo.setMergeNews(v),
                ),
              ),
            ]),
            SectionHeader(left: '持有中 ${held.length} 檔', right: '新聞數 / 來源'),
            RowList(emptyText: '還沒有持股', children: [for (final c in held) row(c)]),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 2),
              child: Row(children: [
                Expanded(child: Text('關注中（還沒買）${watch.length} 檔', style: Theme.of(context).textTheme.bodySmall)),
                const SearchButton(forWatch: true),
              ]),
            ),
            RowList(emptyText: '還沒有關注的股票，按「＋ 加入」', children: [for (final c in watch) row(c)]),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('關注清單全部人共用。買進後會自動出現在「持有中」。',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ] else
            const ScreenerPanel(),
        ],
      ),
    );
  }
}

/// 「選股雷達」：機械化排名，不是投資建議。從候選股池抓當天報價，算今日
/// 漲跌幅、量能、離今天高點的距離，排出「今天表現比較突出」的股票，
/// 附上每一檔的理由。沒有人能保證這些股票之後會賺錢，純粹是資料篩選。
class ScreenerPanel extends StatefulWidget {
  const ScreenerPanel({super.key});

  @override
  State<ScreenerPanel> createState() => _ScreenerPanelState();
}

class _ScreenerPanelState extends State<ScreenerPanel> {
  final _service = PriceService();
  bool _loading = false;
  bool _fullMarket = false;
  List<ScreenerHit>? _hits;
  String? _error;
  int _scanned = 0;
  int _total = 0;

  Future<void> _run(AppRepository repo) async {
    setState(() {
      _loading = true;
      _error = null;
      _hits = null;
      _scanned = 0;
    });
    try {
      final candidates = {
        ...kScreenerCandidateCodes,
        ...repo.heldCodes,
        ...repo.watchlist,
        if (_fullMarket) ...kBuiltinStocksByCode.keys,
      }.toList();
      setState(() => _total = candidates.length);

      final quotes = <ScreenerQuote>[];
      const chunk = 30 * 4; // 每次同時發出 4 批（每批 30 檔）請求，加快全市場掃描
      for (var i = 0; i < candidates.length; i += chunk) {
        final part = candidates.sublist(i, i + chunk > candidates.length ? candidates.length : i + chunk);
        final sub = <List<String>>[];
        for (var j = 0; j < part.length; j += 30) {
          sub.add(part.sublist(j, j + 30 > part.length ? part.length : j + 30));
        }
        final results = await Future.wait(sub.map((s) => _service.fetchScreenerQuotes(s)));
        for (final r in results) {
          quotes.addAll(r);
        }
        if (mounted) setState(() => _scanned = (i + chunk).clamp(0, candidates.length));
      }

      final hits = rankByMomentum(quotes);
      if (mounted) setState(() => _hits = hits);
    } catch (_) {
      if (mounted) setState(() => _error = '掃描失敗，請確認有網路連線後再試一次');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: .35),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            '這是機械化的排名（今天的漲跌幅、量能、股價位置），不是投資建議、'
            '也不是預測——沒有人能保證這些股票之後會賺錢，買賣前務必自己再確認。',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: const Text('全市場掃描', style: TextStyle(fontSize: 13)),
        subtitle: Text(_fullMarket ? '掃全部上市櫃股票（約 2300 檔，較慢）' : '只掃熱門股/ETF 候選池（約 180 檔＋你的持股/關注，較快）',
            style: const TextStyle(fontSize: 11)),
        value: _fullMarket,
        onChanged: _loading ? null : (v) => setState(() => _fullMarket = v),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _loading ? null : () => _run(repo),
          icon: _loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.radar, size: 18),
          label: Text(_loading ? '掃描中… $_scanned / $_total' : '開始掃描'),
        ),
      ),
      const SizedBox(height: 10),
      if (_error != null)
        Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      if (_hits != null) ...[
        SectionHeader(left: '今日動能排行（共 ${_hits!.length} 檔上漲候選）', right: _hits!.isEmpty ? null : '前 5 名特別標記'),
        RowList(
          emptyText: '這次掃描沒有符合條件（今天上漲）的候選股',
          children: [
            for (var i = 0; i < _hits!.length; i++) _ScreenerRow(rank: i + 1, hit: _hits![i], repo: repo),
          ],
        ),
      ],
    ]);
  }
}

class _ScreenerRow extends StatelessWidget {
  final int rank;
  final ScreenerHit hit;
  final AppRepository repo;
  const _ScreenerRow({required this.rank, required this.hit, required this.repo});

  @override
  Widget build(BuildContext context) {
    final code = hit.code;
    final name = repo.nameOf(code);
    final top5 = rank <= 5;
    return InfoRow(
      onTap: () => context.read<ShellController>().open(context, StockRoute(code), nested: true),
      title: Row(children: [
        if (top5)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('#$rank', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        Flexible(child: Text('$code ${name.isEmpty ? '' : name}', overflow: TextOverflow.ellipsis)),
      ]),
      subtitle: Text(hit.reasons.join(' · ')),
      trailingTop: Text('\$${f2(hit.quote.price)}'),
      trailingBottom: Text(pct(hit.quote.changePct, 100), style: TextStyle(color: changeColor(context, hit.quote.changePct))),
    );
  }
}

int clusterNewsCount(List<NewsItem> items, {required bool merge}) =>
    clusterNews(items, merge: merge).length;

/// 個股頁最下面的「最新新聞」預覽：最多 3 則，加一個「看更多新聞」。
class NewsPreview extends StatelessWidget {
  final String code;
  const NewsPreview({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final cache = context.watch<NewsCache>();
    final items = cache.itemsFor(code);
    if (items == null) {
      if (!cache.isLoading(code)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => cache.ensure(code, name: repo.nameOf(code)));
      }
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Row(children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('正在抓新聞…'),
        ]),
      );
    }
    final clusters = clusterNews(items, merge: repo.mergeNews).take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(left: '最新新聞', right: '近 7 天 ${clusterNews(items, merge: repo.mergeNews).length} 則'),
      RowList(
        emptyText: '這段期間沒有新聞',
        children: [
          for (final c in clusters) NewsClusterTile(cluster: c, merge: repo.mergeNews),
          InfoRow(
            onTap: () => context.read<ShellController>().open(context, NewsListRoute(code), nested: true),
            title: const Text('看更多新聞', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    ]);
  }
}

class NewsListDetail extends StatefulWidget {
  final String code;
  const NewsListDetail({super.key, required this.code});

  @override
  State<NewsListDetail> createState() => _NewsListDetailState();
}

class _NewsListDetailState extends State<NewsListDetail> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = context.read<AppRepository>();
      context.read<NewsCache>().ensure(widget.code, name: repo.nameOf(widget.code));
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final cache = context.watch<NewsCache>();
    final items = cache.itemsFor(widget.code);
    final loading = cache.isLoading(widget.code);
    final clusters = items == null ? const <NewsCluster>[] : clusterNews(items, merge: repo.mergeNews);

    return Scaffold(
      appBar: DetailAppBar(
        title: Text('${widget.code} ${repo.nameOf(widget.code)} 新聞'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
            onPressed: loading
                ? null
                : () => cache.ensure(widget.code, name: repo.nameOf(widget.code), force: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          StatGrid(columns: 3, stats: [
            ('期間', '7 天', null),
            (repo.mergeNews ? '合併後' : '全部', '${clusters.length} 則', null),
            ('原始', '${items?.length ?? 0} 則', null),
          ]),
          const SizedBox(height: 8),
          if (loading && items == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else
            RowList(
              emptyText: '這段期間沒有新聞，或抓取失敗（需要網路連線）',
              children: [for (final c in clusters) NewsClusterTile(cluster: c, merge: repo.mergeNews, expanded: true)],
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context
                .read<ShellController>()
                .open(context, StockRoute(widget.code), nested: true),
            child: Text('看 ${repo.nameOf(widget.code)} 的股價與交易 ›'),
          ),
        ],
      ),
    );
  }
}

class NewsClusterTile extends StatefulWidget {
  final NewsCluster cluster;
  final bool merge;
  final bool expanded;
  const NewsClusterTile({super.key, required this.cluster, required this.merge, this.expanded = false});

  @override
  State<NewsClusterTile> createState() => _NewsClusterTileState();
}

class _NewsClusterTileState extends State<NewsClusterTile> {
  bool _open = false;

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法開啟這則新聞')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cluster;
    final extra = c.items.length - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => _openLink(c.primary.link),
          child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ),
        const SizedBox(height: 2),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('${c.primary.source} · ${c.latest.month}/${c.latest.day.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (widget.merge && extra > 0)
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Text('  另有 $extra 家來源報導 ${_open ? '▴' : '▾'}',
                  style: const TextStyle(fontSize: 12, color: Colors.teal)),
            ),
        ]),
        if (widget.merge && _open)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in c.items.where((i) => i != c.primary))
                  InkWell(
                    onTap: () => _openLink(i.link),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${i.source} ›', style: const TextStyle(fontSize: 12, color: Colors.teal)),
                    ),
                  ),
              ],
            ),
          ),
      ]),
    );
  }
}
