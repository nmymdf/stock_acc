/// App 的整體殼：左邊選單（總覽／持股／資訊／交易／設定），視窗夠寬時
/// 中間是列表、右邊直接顯示明細；視窗窄（手機）時明細用一般的換頁。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import 'screens/holdings.dart';
import 'screens/info.dart';
import 'screens/overview.dart';
import 'screens/search.dart';
import 'screens/settings.dart';
import 'screens/trades.dart';
import 'widgets/common.dart';

enum AppTab { overview, holdings, info, trades, settings }

extension AppTabX on AppTab {
  String get label => switch (this) {
        AppTab.overview => '總覽',
        AppTab.holdings => '持股',
        AppTab.info => '資訊',
        AppTab.trades => '交易',
        AppTab.settings => '設定',
      };
  IconData get icon => switch (this) {
        AppTab.overview => Icons.donut_small,
        AppTab.holdings => Icons.list_alt,
        AppTab.info => Icons.auto_awesome,
        AppTab.trades => Icons.swap_vert,
        AppTab.settings => Icons.settings,
      };
}

/// 右邊明細窗格（或手機上換頁後的整頁）要顯示什麼內容。
sealed class DetailRoute {
  const DetailRoute();
}

class PersonRoute extends DetailRoute {
  final String personId;
  const PersonRoute(this.personId);
}

class StockRoute extends DetailRoute {
  final String code;
  final ScopeFilter scope;
  const StockRoute(this.code, {this.scope = const ScopeFilter.all()});
}

class NewsListRoute extends DetailRoute {
  final String code;
  const NewsListRoute(this.code);
}

class TradeFormRoute extends DetailRoute {
  final String? tradeId;
  final String? presetCode;
  final String? presetAccountId;
  const TradeFormRoute({this.tradeId, this.presetCode, this.presetAccountId});
}

class SearchRoute extends DetailRoute {
  final bool forWatch;
  const SearchRoute({this.forWatch = false});
}

/// 掌管目前選到的分頁、明細堆疊（寬螢幕用）、每個分頁各自的換頁堆疊（窄螢幕用）。
class ShellController extends ChangeNotifier {
  bool wide = false;
  AppTab tab = AppTab.overview;
  List<DetailRoute> stack = [];

  final Map<AppTab, GlobalKey<NavigatorState>> navKeys = {
    for (final t in AppTab.values) t: GlobalKey<NavigatorState>(),
  };

  void setWide(bool w) {
    if (wide == w) return;
    wide = w;
    notifyListeners();
  }

  /// 從中間列表點一個項目：寬螢幕時把明細堆疊重置成只有這一項；
  /// 窄螢幕時整頁換過去。[nested] 代表是在明細窗格「裡面」再往下點一層
  /// （例如個股頁點某一筆交易），寬螢幕時疊加而不是取代。
  void open(BuildContext context, DetailRoute route, {bool nested = false}) {
    if (wide) {
      stack = nested ? [...stack, route] : [route];
      notifyListeners();
    } else {
      navKeys[tab]!.currentState?.push(
            MaterialPageRoute(builder: (_) => DetailScaffold(route: route)),
          );
    }
  }

  void closeDetail() {
    if (stack.isEmpty) return;
    stack = stack.sublist(0, stack.length - 1);
    notifyListeners();
  }

  void switchTab(AppTab t) {
    if (tab == t) return;
    tab = t;
    stack = [];
    notifyListeners();
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _breakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ShellController(),
      child: Consumer<ShellController>(
        builder: (context, shell, _) {
          return LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= _breakpoint;
            WidgetsBinding.instance.addPostFrameCallback((_) => shell.setWide(wide));
            return wide ? _WideLayout(shell: shell) : _NarrowLayout(shell: shell);
          });
        },
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  final ShellController shell;
  const _WideLayout({required this.shell});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final repo = context.watch<AppRepository>();
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.tab.index,
            onDestinationSelected: (i) => shell.switchTab(AppTab.values[i]),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('股票記帳', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '資料存在這台電腦\n不上雲端',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final t in AppTab.values)
                NavigationRailDestination(icon: Icon(t.icon), label: Text(t.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 420,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border(right: BorderSide(color: scheme.outlineVariant))),
              child: MasterPage(tab: shell.tab, repo: repo),
            ),
          ),
          Expanded(
            child: shell.stack.isEmpty
                ? const EmptyHint(text: '點左邊列表裡的項目\n看詳細內容')
                : DetailScaffold(route: shell.stack.last, embedded: true),
          ),
        ],
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  final ShellController shell;
  const _NarrowLayout({required this.shell});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    return Scaffold(
      body: IndexedStack(
        index: shell.tab.index,
        children: [
          for (final t in AppTab.values)
            Navigator(
              key: shell.navKeys[t],
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => MasterPage(tab: t, repo: repo),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.tab.index,
        onDestinationSelected: (i) => shell.switchTab(AppTab.values[i]),
        destinations: [
          for (final t in AppTab.values)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}

/// 依目前分頁決定中間（或窄螢幕整頁）要顯示哪個列表畫面。
class MasterPage extends StatelessWidget {
  final AppTab tab;
  final AppRepository repo;
  const MasterPage({super.key, required this.tab, required this.repo});

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      AppTab.overview => const OverviewScreen(),
      AppTab.holdings => const HoldingsScreen(),
      AppTab.info => const InfoScreen(),
      AppTab.trades => const TradesScreen(),
      AppTab.settings => const SettingsScreen(),
    };
  }
}

/// 明細內容的外殼：寬螢幕時是右邊窗格（有自己的返回鍵回到上一層明細），
/// 窄螢幕時是整頁（用系統的返回手勢／按鈕）。
class DetailScaffold extends StatelessWidget {
  final DetailRoute route;
  final bool embedded;
  const DetailScaffold({super.key, required this.route, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = switch (route) {
      PersonRoute r => PersonDetail(personId: r.personId),
      StockRoute r => StockDetail(code: r.code, scope: r.scope),
      NewsListRoute r => NewsListDetail(code: r.code),
      TradeFormRoute r => TradeFormDetail(tradeId: r.tradeId, presetCode: r.presetCode, presetAccountId: r.presetAccountId),
      SearchRoute r => SearchDetail(forWatch: r.forWatch),
    };
    if (!embedded) {
      return content; // 窄螢幕：每個明細畫面自己是一個 Scaffold（見各檔案）。
    }
    return content;
  }
}
