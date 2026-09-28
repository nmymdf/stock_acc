/// App 的完整資料狀態：人、帳戶、交易、關注清單、現價快取、設定。
///
/// 整包資料都可以序列化成一個 JSON 物件，這就是本機存檔，也是備份檔的格式——
/// 「匯出備份」就是把這個 JSON 存成檔案，「匯入」就是讀回來整包取代。
library;

import '../models/models.dart';

class AppData {
  List<Person> persons;
  List<BrokerAccount> accounts;
  List<Trade> trades;
  List<WatchItem> watchlist;

  /// 使用者手動輸入或按「更新股價」抓回來的現價，key 是股票代號。
  Map<String, PriceQuote> quotes;

  /// 使用者交易過但不在內建清單裡的股票代號 → 自己輸入的名稱。
  Map<String, String> customNames;

  AppSettings settings;

  AppData({
    List<Person>? persons,
    List<BrokerAccount>? accounts,
    List<Trade>? trades,
    List<WatchItem>? watchlist,
    Map<String, PriceQuote>? quotes,
    Map<String, String>? customNames,
    AppSettings? settings,
  })  : persons = persons ?? [],
        accounts = accounts ?? [],
        trades = trades ?? [],
        watchlist = watchlist ?? [],
        quotes = quotes ?? {},
        customNames = customNames ?? {},
        settings = settings ?? AppSettings();

  /// 目前版本號，之後修改存檔格式時用來判斷要不要轉換舊資料。
  static const int kSchemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'schemaVersion': kSchemaVersion,
        'persons': persons.map((e) => e.toJson()).toList(),
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'trades': trades.map((e) => e.toJson()).toList(),
        'watchlist': watchlist.map((e) => e.toJson()).toList(),
        'quotes': quotes.map((k, v) => MapEntry(k, v.toJson())),
        'customNames': customNames,
        'settings': settings.toJson(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        persons: (j['persons'] as List? ?? [])
            .map((e) => Person.fromJson(e as Map<String, dynamic>))
            .toList(),
        accounts: (j['accounts'] as List? ?? [])
            .map((e) => BrokerAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
        trades: (j['trades'] as List? ?? [])
            .map((e) => Trade.fromJson(e as Map<String, dynamic>))
            .toList(),
        watchlist: (j['watchlist'] as List? ?? [])
            .map((e) => WatchItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        quotes: (j['quotes'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, PriceQuote.fromJson(v as Map<String, dynamic>)),
        ),
        customNames: (j['customNames'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as String)),
        settings: j['settings'] == null
            ? AppSettings()
            : AppSettings.fromJson(j['settings'] as Map<String, dynamic>),
      );

  /// 內建範例資料：第一次啟用、還沒有任何人時顯示，讓畫面不是空的。
  /// 只在完全沒有資料時使用一次，使用者新增第一個人之後就不會再出現。
  factory AppData.sample() {
    final now = DateTime.now();
    final me = Person(id: 'p-sample', name: '我', updatedAt: now);
    final acc = BrokerAccount(
      id: 'a-sample',
      personId: me.id,
      broker: '示範券商',
      discount: 6,
      updatedAt: now,
    );
    return AppData(persons: [me], accounts: [acc]);
  }
}
