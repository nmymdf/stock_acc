/// 內建的台股代號 → 名稱對照表，輸入代號時不用連網也能帶出名稱。
///
/// 只收錄常見的上市櫃股票和 ETF，不是完整清單。查不到的代號，新增交易時
/// 仍然可以輸入，名稱欄位留給使用者自己填，之後照原樣顯示。
library;

class StockInfo {
  final String code;
  final String name;
  final String market; // 上市 / 上櫃

  const StockInfo(this.code, this.name, this.market);
}

const List<StockInfo> kBuiltinStocks = [
  StockInfo('2330', '台積電', '上市'),
  StockInfo('2317', '鴻海', '上市'),
  StockInfo('2454', '聯發科', '上市'),
  StockInfo('2412', '中華電', '上市'),
  StockInfo('2881', '富邦金', '上市'),
  StockInfo('2882', '國泰金', '上市'),
  StockInfo('2891', '中信金', '上市'),
  StockInfo('2603', '長榮', '上市'),
  StockInfo('2609', '陽明', '上市'),
  StockInfo('2308', '台達電', '上市'),
  StockInfo('2382', '廣達', '上市'),
  StockInfo('2357', '華碩', '上市'),
  StockInfo('2379', '瑞昱', '上市'),
  StockInfo('3711', '日月光投控', '上市'),
  StockInfo('1301', '台塑', '上市'),
  StockInfo('1303', '南亞', '上市'),
  StockInfo('1216', '統一', '上市'),
  StockInfo('2002', '中鋼', '上市'),
  StockInfo('2886', '兆豐金', '上市'),
  StockInfo('2884', '玉山金', '上市'),
  StockInfo('2885', '元大金', '上市'),
  StockInfo('2892', '第一金', '上市'),
  StockInfo('2880', '華南金', '上市'),
  StockInfo('5871', '中租-KY', '上市'),
  StockInfo('3008', '大立光', '上市'),
  StockInfo('2395', '研華', '上市'),
  StockInfo('2408', '南亞科', '上市'),
  StockInfo('3034', '聯詠', '上市'),
  StockInfo('6415', '矽力-KY', '上市'),
  StockInfo('2327', '國巨', '上市'),
  StockInfo('1101', '台泥', '上市'),
  StockInfo('1102', '亞泥', '上市'),
  StockInfo('2207', '和泰車', '上市'),
  StockInfo('2912', '統一超', '上市'),
  StockInfo('9910', '豐泰', '上市'),
  StockInfo('5347', '世界', '上櫃'),
  StockInfo('6488', '環球晶', '上櫃'),
  StockInfo('3443', '創意', '上櫃'),
  StockInfo('6669', '緯穎', '上市'),
  StockInfo('2345', '智邦', '上市'),
  StockInfo('3037', '欣興', '上市'),
  StockInfo('0050', '元大台灣50', '上市'),
  StockInfo('0056', '元大高股息', '上市'),
  StockInfo('00878', '國泰永續高股息', '上市'),
  StockInfo('00919', '群益台灣精選高息', '上市'),
  StockInfo('00929', '復華台灣科技優息', '上市'),
  StockInfo('00713', '元大台灣高息低波', '上市'),
  StockInfo('006208', '富邦台50', '上市'),
];

final Map<String, StockInfo> kBuiltinStocksByCode = {
  for (final s in kBuiltinStocks) s.code: s,
};

/// 查代號或名稱關鍵字（找開頭符合代號，或名稱包含關鍵字的股票）。
List<StockInfo> searchStocks(String query) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  return kBuiltinStocks
      .where((s) => s.code.startsWith(q) || s.name.contains(q))
      .toList();
}
