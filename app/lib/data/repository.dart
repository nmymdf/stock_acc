/// App 的資料中樞：所有畫面都透過這個 [AppRepository] 讀資料、做修改。
/// 每次修改都會存檔（本機 JSON 檔），也會通知畫面重畫。
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../logic/stats.dart';
import '../models/models.dart';
import 'app_data.dart';
import 'group_store.dart';
import 'local_store.dart';
import 'stock_catalog.dart';

const _uuid = Uuid();

/// 篩選條件：全部人、某個人、或某個帳戶。用在持股、交易紀錄頁的篩選列，
/// 以及「總覽 → 個人」「持股 → 個股」這類要限定範圍再統計的地方。
class ScopeFilter {
  final String? personId;
  final String? accountId;

  const ScopeFilter({this.personId, this.accountId});
  const ScopeFilter.all() : this();

  bool matches(BrokerAccount a) {
    if (accountId != null) return a.id == accountId;
    if (personId != null) return a.personId == personId;
    return true;
  }
}

class AppRepository extends ChangeNotifier {
  final LocalStore _store = LocalStore();
  AppData _data = AppData();
  GroupRegistry _registry = GroupRegistry(groups: [], activeId: '');
  bool loaded = false;

  /// 資料實際存放的資料夾路徑，設定頁顯示用（方便使用者自己去對照檔案）。
  String storageDirPath = '';

  AppData get data => _data;

  // ---------------- 群體（完全獨立的資料） ----------------

  List<GroupInfo> get groups => List.unmodifiable(_registry.groups);
  String get activeGroupId => _registry.activeId;
  String get activeGroupName =>
      _registry.groups.where((g) => g.id == _registry.activeId).firstOrNull?.name ?? '';

  Future<void> load() async {
    storageDirPath = await _store.dirPath();
    var registryJson = await _store.readNamed(LocalStore.groupsFileName);
    if (registryJson == null) {
      // 第一次用這個版本：把舊版唯一的那份資料（如果有）搬進「預設」群體，
      // 沒有的話就是全新安裝，用範例資料開局。
      final legacy = await _store.readNamed(LocalStore.legacyFileName);
      final id = _uuid.v4();
      _registry = GroupRegistry(
        groups: [GroupInfo(id: id, name: '預設', createdAt: DateTime.now())],
        activeId: id,
      );
      _data = legacy == null ? AppData.sample() : AppData.fromJson(legacy);
      await _store.writeNamed(LocalStore.groupsFileName, _registry.toJson());
      await _store.writeNamed(LocalStore.dataFileNameFor(id), _data.toJson());
    } else {
      _registry = GroupRegistry.fromJson(registryJson);
      final dataJson = await _store.readNamed(LocalStore.dataFileNameFor(_registry.activeId));
      _data = dataJson == null ? AppData.sample() : AppData.fromJson(dataJson);
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    await _store.writeNamed(LocalStore.dataFileNameFor(_registry.activeId), _data.toJson());
  }

  Future<void> _saveRegistry() async {
    await _store.writeNamed(LocalStore.groupsFileName, _registry.toJson());
  }

  /// 新增一個完全獨立的群體，資料是空的（不是範例資料），並立刻切換過去。
  Future<GroupInfo> addGroup(String name) async {
    final g = GroupInfo(id: _uuid.v4(), name: name, createdAt: DateTime.now());
    _registry.groups.add(g);
    await _saveRegistry();
    // 新群體先落地一份空白資料，切過去的時候才不會被 switchGroup 的
    // 「找不到檔案就用範例資料」那條安全網誤判成要塞示範資料進來。
    await _store.writeNamed(LocalStore.dataFileNameFor(g.id), AppData().toJson());
    await switchGroup(g.id);
    return g;
  }

  Future<void> renameGroup(String id, String name) async {
    final g = _registry.groups.where((x) => x.id == id).firstOrNull;
    if (g == null) return;
    g.name = name;
    await _saveRegistry();
    notifyListeners();
  }

  /// 刪除一個群體，連同它的記帳資料一起刪除（無法復原）。至少要留一個群體。
  Future<void> deleteGroup(String id) async {
    if (_registry.groups.length <= 1) return;
    final wasActive = _registry.activeId == id;
    _registry.groups.removeWhere((g) => g.id == id);
    await _store.deleteNamed(LocalStore.dataFileNameFor(id));
    if (wasActive) {
      await switchGroup(_registry.groups.first.id);
    } else {
      await _saveRegistry();
    }
  }

  /// 切換到另一個群體：整個 App（總覽、持股、交易、關注清單……）都會變成
  /// 那個群體的內容，跟現在這個完全獨立、不會混在一起算。
  Future<void> switchGroup(String id) async {
    if (!_registry.groups.any((g) => g.id == id)) return;
    _registry.activeId = id;
    await _saveRegistry();
    final dataJson = await _store.readNamed(LocalStore.dataFileNameFor(id));
    _data = dataJson == null ? AppData.sample() : AppData.fromJson(dataJson);
    if (dataJson == null) await _save();
    notifyListeners();
  }

  /// 匯入備份：整包取代「目前這個群體」的資料，不影響其他群體。
  Future<void> replaceAll(Map<String, dynamic> json) async {
    await _mutate(() => _data = AppData.fromJson(json));
  }

  /// 匯出「所有群體」：群體清單 + 每個群體各自完整的記帳資料，換裝置時
  /// 一次全部帶過去用（跟「匯出備份」不一樣，那個只匯出目前這一個群體）。
  Future<Map<String, dynamic>> exportAllGroups() async {
    final groupsData = <String, dynamic>{};
    for (final g in _registry.groups) {
      final json = g.id == _registry.activeId
          ? _data.toJson()
          : await _store.readNamed(LocalStore.dataFileNameFor(g.id));
      groupsData[g.id] = json ?? AppData().toJson();
    }
    return {'registry': _registry.toJson(), 'groupsData': groupsData};
  }

  /// 匯入「所有群體」備份：備份裡的每個群體都會被建立（本機沒有的話）或
  /// 覆蓋（本機已經有同一個群體 id 的話），不會刪掉匯入前本機已經有、
  /// 但備份裡沒有的其他群體。匯入完自動切到備份原本使用中的那個群體。
  Future<void> importAllGroups(Map<String, dynamic> json) async {
    final backupRegistry = GroupRegistry.fromJson(json['registry'] as Map<String, dynamic>);
    final groupsData = json['groupsData'] as Map<String, dynamic>;
    for (final g in backupRegistry.groups) {
      if (!_registry.groups.any((x) => x.id == g.id)) {
        _registry.groups.add(GroupInfo(id: g.id, name: g.name, createdAt: g.createdAt));
      }
      final data = groupsData[g.id] as Map<String, dynamic>?;
      await _store.writeNamed(LocalStore.dataFileNameFor(g.id), data ?? AppData().toJson());
    }
    await _saveRegistry();
    final targetId = _registry.groups.any((g) => g.id == backupRegistry.activeId)
        ? backupRegistry.activeId
        : _registry.groups.first.id;
    await switchGroup(targetId);
  }

  Future<void> _mutate(void Function() change) async {
    change();
    notifyListeners();
    await _save();
  }

  // ---------------- 人 / 帳戶 ----------------

  List<Person> get persons => List.unmodifiable(_data.persons);

  List<BrokerAccount> accountsOf(String personId) =>
      _data.accounts.where((a) => a.personId == personId).toList();

  Person? personById(String id) =>
      _data.persons.where((p) => p.id == id).firstOrNull;

  BrokerAccount? accountById(String id) =>
      _data.accounts.where((a) => a.id == id).firstOrNull;

  Future<Person> addPerson(String name) async {
    final p = Person(id: _uuid.v4(), name: name, updatedAt: DateTime.now());
    await _mutate(() => _data.persons.add(p));
    return p;
  }

  Future<void> renamePerson(String id, String name) async {
    await _mutate(() {
      final p = personById(id);
      if (p != null) {
        p.name = name;
        p.updatedAt = DateTime.now();
      }
    });
  }

  /// 刪除一個人，連同他底下的帳戶和交易一起刪除。
  Future<void> removePerson(String id) async {
    await _mutate(() {
      final accIds = accountsOf(id).map((a) => a.id).toSet();
      _data.trades.removeWhere((t) => accIds.contains(t.accountId));
      _data.accounts.removeWhere((a) => a.personId == id);
      _data.persons.removeWhere((p) => p.id == id);
    });
  }

  Future<BrokerAccount> addAccount({
    required String personId,
    required String broker,
    required double discount,
  }) async {
    final a = BrokerAccount(
      id: _uuid.v4(),
      personId: personId,
      broker: broker,
      discount: discount,
      updatedAt: DateTime.now(),
    );
    await _mutate(() => _data.accounts.add(a));
    return a;
  }

  Future<void> updateAccount(String id,
      {String? broker, double? discount}) async {
    await _mutate(() {
      final a = accountById(id);
      if (a == null) return;
      if (broker != null) a.broker = broker;
      if (discount != null) a.discount = discount;
      a.updatedAt = DateTime.now();
    });
  }

  /// 刪除一個帳戶，連同它底下的交易一起刪除。
  Future<void> removeAccount(String id) async {
    await _mutate(() {
      _data.trades.removeWhere((t) => t.accountId == id);
      _data.accounts.removeWhere((a) => a.id == id);
    });
  }

  // ---------------- 交易 ----------------

  List<Trade> get trades => List.unmodifiable(_data.trades);

  Trade? tradeById(String id) =>
      _data.trades.where((t) => t.id == id).firstOrNull;

  Future<Trade> addTrade({
    required String accountId,
    required DateTime date,
    required String code,
    required String name,
    required TradeSide side,
    required int shares,
    required double price,
    required int fee,
    required int tax,
  }) async {
    final t = Trade(
      id: _uuid.v4(),
      accountId: accountId,
      date: date,
      code: code,
      name: name,
      side: side,
      shares: shares,
      price: price,
      fee: fee,
      tax: tax,
      updatedAt: DateTime.now(),
    );
    await _mutate(() {
      _data.trades.add(t);
      _rememberCustomName(code, name);
    });
    return t;
  }

  Future<void> updateTrade(
    String id, {
    DateTime? date,
    String? code,
    String? name,
    TradeSide? side,
    int? shares,
    double? price,
    int? fee,
    int? tax,
  }) async {
    await _mutate(() {
      final t = tradeById(id);
      if (t == null) return;
      if (date != null) t.date = date;
      if (code != null) t.code = code;
      if (name != null) t.name = name;
      if (side != null) t.side = side;
      if (shares != null) t.shares = shares;
      if (price != null) t.price = price;
      if (fee != null) t.fee = fee;
      if (tax != null) t.tax = tax;
      t.updatedAt = DateTime.now();
      if (code != null || name != null) _rememberCustomName(t.code, t.name);
    });
  }

  Future<void> removeTrade(String id) async {
    await _mutate(() => _data.trades.removeWhere((t) => t.id == id));
  }

  void _rememberCustomName(String code, String name) {
    if (name.isEmpty || kBuiltinStocksByCode.containsKey(code)) return;
    _data.customNames[code] = name;
  }

  // ---------------- 股票名稱 / 現價 ----------------

  /// 代號查名稱：先查內建清單，查不到就查使用者自己輸入過的名稱，還是查不到就是空字串。
  String nameOf(String code) =>
      kBuiltinStocksByCode[code]?.name ?? _data.customNames[code] ?? '';

  String marketOf(String code) => kBuiltinStocksByCode[code]?.market ?? '';

  PriceQuote? quoteOf(String code) => _data.quotes[code];

  Map<String, double> get priceMap => {
        for (final e in _data.quotes.entries) e.key: e.value.price,
      };

  Future<void> setQuote(String code, double price, {double change = 0}) async {
    await _mutate(() {
      _data.quotes[code] = PriceQuote(
        price: price,
        change: change,
        updatedAt: DateTime.now(),
      );
    });
  }

  /// 一次寫入多支股票的現價（例如按「更新股價」抓回一批之後）。
  Future<void> setQuotes(Map<String, ({double price, double change})> map) async {
    await _mutate(() {
      final now = DateTime.now();
      for (final e in map.entries) {
        _data.quotes[e.key] = PriceQuote(
          price: e.value.price,
          change: e.value.change,
          updatedAt: now,
        );
      }
    });
  }

  // ---------------- 關注清單 ----------------

  List<String> get watchlist =>
      List.unmodifiable(_data.watchlist.map((w) => w.code));

  bool isWatching(String code) =>
      _data.watchlist.any((w) => w.code == code);

  Future<void> toggleWatch(String code) async {
    await _mutate(() {
      if (isWatching(code)) {
        _data.watchlist.removeWhere((w) => w.code == code);
      } else {
        _data.watchlist.add(WatchItem(code: code, addedAt: DateTime.now()));
      }
    });
  }

  // ---------------- 設定 ----------------

  bool get mergeNews => _data.settings.mergeNews;

  Future<void> setMergeNews(bool v) async {
    await _mutate(() => _data.settings.mergeNews = v);
  }

  // ---------------- 統計 ----------------

  List<BrokerAccount> _accountsMatching(ScopeFilter f) =>
      _data.accounts.where(f.matches).toList();

  /// 一個代號目前有哪些帳戶持有（不論篩選範圍），用在個股頁「誰持有」。
  List<AccountPosition> positionsForCode(String code, {ScopeFilter? scope}) {
    final accIds =
        _accountsMatching(scope ?? const ScopeFilter.all()).map((a) => a.id).toSet();
    final tradesOfCode =
        _data.trades.where((t) => t.code == code && accIds.contains(t.accountId));
    return computeAccountPositions(tradesOfCode);
  }

  /// [scope] 範圍內、依代號彙總的統計（總覽、持股、個人頁都用這個）。
  List<StockSummary> summarize(ScopeFilter scope) {
    final accIds = _accountsMatching(scope).map((a) => a.id).toSet();
    final relevant = _data.trades.where((t) => accIds.contains(t.accountId));
    final positions = computeAccountPositions(relevant);
    return summarizeByCode(positions, priceMap);
  }

  Totals totalsFor(ScopeFilter scope) => totalsOf(summarize(scope));

  /// 所有目前有交易紀錄的股票代號（給交易頁的「股票」篩選選單用）。
  List<String> get tradedCodes =>
      {for (final t in _data.trades) t.code}.toList()..sort();

  /// 目前持有中的股票代號（總股數 > 0）。
  List<String> get heldCodes => summarize(const ScopeFilter.all())
      .where((s) => s.shares > 0)
      .map((s) => s.code)
      .toList();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
