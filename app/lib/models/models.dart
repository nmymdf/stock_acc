/// 資料模型：人、券商帳戶、交易、關注股票。
///
/// 每筆資料都有唯一的 [id] 和 [updatedAt]（修改時間），是刻意預留的欄位——
/// 現在只用來排序和除錯，第二階段加雲端同步時，可以直接拿來判斷哪筆資料比較新。
library;

/// 交易的買賣方向。
enum TradeSide { buy, sell }

/// 一個人（例如「小明」），底下可以有多個券商帳戶。
class Person {
  final String id;
  String name;
  DateTime updatedAt;

  Person({required this.id, required this.name, required this.updatedAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        id: j['id'] as String,
        name: j['name'] as String,
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

/// 一個券商帳戶，掛在某個人底下。手續費只設一個折扣（不精細），
/// 例如犇亞打 1.68 折、新光打 2.8 折。
class BrokerAccount {
  final String id;
  final String personId;
  String broker;

  /// 折扣，例如 2.8 代表 2.8 折。10 = 不打折。
  double discount;
  DateTime updatedAt;

  BrokerAccount({
    required this.id,
    required this.personId,
    required this.broker,
    required this.discount,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'broker': broker,
        'discount': discount,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory BrokerAccount.fromJson(Map<String, dynamic> j) => BrokerAccount(
        id: j['id'] as String,
        personId: j['personId'] as String,
        broker: j['broker'] as String,
        discount: (j['discount'] as num).toDouble(),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

/// 一筆買進或賣出的交易紀錄。
class Trade {
  final String id;
  final String accountId;
  DateTime date;
  String code;

  /// 交易當下的股票名稱快照，代號查不到名稱時還能顯示。
  String name;
  TradeSide side;
  int shares;
  double price;
  int fee;
  int tax;
  DateTime updatedAt;

  Trade({
    required this.id,
    required this.accountId,
    required this.date,
    required this.code,
    required this.name,
    required this.side,
    required this.shares,
    required this.price,
    required this.fee,
    required this.tax,
    required this.updatedAt,
  });

  double get amount => shares * price;

  /// 這筆交易實際付出或收到的金額：買進是負的（付錢），賣出是正的（收錢）。
  double get netCashFlow =>
      side == TradeSide.buy ? -(amount + fee) : amount - fee - tax;

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'date': date.toIso8601String(),
        'code': code,
        'name': name,
        'side': side.name,
        'shares': shares,
        'price': price,
        'fee': fee,
        'tax': tax,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Trade.fromJson(Map<String, dynamic> j) => Trade(
        id: j['id'] as String,
        accountId: j['accountId'] as String,
        date: DateTime.parse(j['date'] as String),
        code: j['code'] as String,
        name: j['name'] as String? ?? '',
        side: TradeSide.values.byName(j['side'] as String),
        shares: j['shares'] as int,
        price: (j['price'] as num).toDouble(),
        fee: j['fee'] as int,
        tax: j['tax'] as int,
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

/// 關注中但還沒買的股票。全部人共用一份清單。
class WatchItem {
  final String code;
  DateTime addedAt;

  WatchItem({required this.code, required this.addedAt});

  Map<String, dynamic> toJson() => {
        'code': code,
        'addedAt': addedAt.toIso8601String(),
      };

  factory WatchItem.fromJson(Map<String, dynamic> j) => WatchItem(
        code: j['code'] as String,
        addedAt: DateTime.parse(j['addedAt'] as String),
      );
}

/// 手動輸入或抓回來的現價，存起來下次開 App 還在。
class PriceQuote {
  double price;
  double change;
  DateTime updatedAt;

  PriceQuote({
    required this.price,
    required this.change,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'price': price,
        'change': change,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PriceQuote.fromJson(Map<String, dynamic> j) => PriceQuote(
        price: (j['price'] as num).toDouble(),
        change: (j['change'] as num).toDouble(),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

/// App 全域設定。
class AppSettings {
  /// 新聞頁「合併相同新聞」開關。
  bool mergeNews;

  AppSettings({this.mergeNews = true});

  Map<String, dynamic> toJson() => {'mergeNews': mergeNews};

  factory AppSettings.fromJson(Map<String, dynamic> j) =>
      AppSettings(mergeNews: j['mergeNews'] as bool? ?? true);
}
