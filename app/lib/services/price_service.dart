/// 抓證交所的股價，有兩層來源：
/// 1. 「基本市況報導」即時報價——免費不用帳號，但不是正式公開的 API，
///    對某些商品（實測發現像 00679B 這種債券型 ETF）常常查不到即時欄位。
/// 2. 查不到即時價的股票，改抓證交所**官方公開資料**的「每日收盤行情」
///    當備援，抓不到即時價至少還能有當天（或最近一個交易日）的收盤價。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/stock_catalog.dart';

class PriceResult {
  final String code;
  final double price;
  final double change;

  const PriceResult(this.code, this.price, this.change);
}

/// 「選股雷達」用的完整當日報價：比 [PriceResult] 多開盤/最高/最低/成交量，
/// 用來算漲跌幅、量能、離今天高點的距離這些排序依據。
class ScreenerQuote {
  final String code;
  final double price;
  final double prevClose;
  final double open;
  final double high;
  final double low;
  final int volumeLots; // 成交量，單位：張

  const ScreenerQuote({
    required this.code,
    required this.price,
    required this.prevClose,
    required this.open,
    required this.high,
    required this.low,
    required this.volumeLots,
  });

  double get changePct => prevClose == 0 ? 0 : (price - prevClose) / prevClose * 100;
}

class PriceService {
  /// 一次最多查幾支，太多的話分批查詢，避免單一請求太長被拒。
  static const _batchSize = 30;

  /// 查一批代號的現價。查不到、逾時、格式不對的股票會直接跳過，
  /// 不會讓整批查詢失敗——回傳的 Map 可能比要求的代號少。
  Future<Map<String, PriceResult>> fetchQuotes(List<String> codes) async {
    final result = <String, PriceResult>{};
    for (var i = 0; i < codes.length; i += _batchSize) {
      final batch = codes.sublist(
        i,
        i + _batchSize > codes.length ? codes.length : i + _batchSize,
      );
      final part = await _fetchRealtimeBatch(batch);
      result.addAll(part);
    }

    // 即時來源沒抓到的股票，改抓官方每日收盤價當備援（目前只有上市，上櫃的
    // 官方公開資料格式不同，之後有需要再補）。
    final missing = codes.where((c) => !result.containsKey(c)).toList();
    if (missing.isNotEmpty) {
      final fallback = await _fetchDailyCloseFallback(missing);
      result.addAll(fallback);
    }
    return result;
  }

  /// 「選股雷達」專用：查一批代號當天完整的開高低量，查不到、逾時的股票
  /// 直接跳過（回傳的清單可能比要求的代號少），不影響其他候選股。
  Future<List<ScreenerQuote>> fetchScreenerQuotes(List<String> codes) async {
    final out = <ScreenerQuote>[];
    for (var i = 0; i < codes.length; i += _batchSize) {
      final batch = codes.sublist(
        i,
        i + _batchSize > codes.length ? codes.length : i + _batchSize,
      );
      out.addAll(await _fetchScreenerBatch(batch));
    }
    return out;
  }

  Future<List<ScreenerQuote>> _fetchScreenerBatch(List<String> codes) async {
    final exCh = codes
        .map((c) {
          final market = kBuiltinStocksByCode[c]?.market;
          final prefix = market == '上櫃' ? 'otc' : 'tse';
          return '${prefix}_$c.tw';
        })
        .join('|');
    final uri = Uri.https(
      'mis.twse.com.tw',
      '/stock/api/getStockInfo.jsp',
      {'ex_ch': exCh, 'json': '1', 'delay': '0'},
    );
    try {
      final res = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['msgArray'] as List? ?? [];
      final out = <ScreenerQuote>[];
      for (final raw in list) {
        final row = raw as Map<String, dynamic>;
        final code = row['c'] as String?;
        if (code == null) continue;
        final zStr = row['z'] as String?; // 成交價，'-' 代表還沒成交
        final yStr = row['y'] as String?; // 昨收
        final price = _num((zStr == '-' ? null : zStr) ?? yStr);
        final prevClose = _num(yStr);
        if (price == null || prevClose == null || prevClose == 0) continue;
        out.add(ScreenerQuote(
          code: code,
          price: price,
          prevClose: prevClose,
          open: _num(row['o']) ?? price,
          high: _num(row['h']) ?? price,
          low: _num(row['l']) ?? price,
          volumeLots: (_num(row['v']) ?? 0).round(),
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, PriceResult>> _fetchRealtimeBatch(List<String> codes) async {
    // 上市用 tse_ 前綴、上櫃用 otc_，兩種都查一次比較保險（查錯市場證交所會回空值）。
    final exCh = codes
        .map((c) {
          final market = kBuiltinStocksByCode[c]?.market;
          final prefix = market == '上櫃' ? 'otc' : 'tse';
          return '${prefix}_$c.tw';
        })
        .join('|');
    final uri = Uri.https(
      'mis.twse.com.tw',
      '/stock/api/getStockInfo.jsp',
      {'ex_ch': exCh, 'json': '1', 'delay': '0'},
    );
    try {
      final res = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return {};
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['msgArray'] as List? ?? [];
      final out = <String, PriceResult>{};
      for (final raw in list) {
        final row = raw as Map<String, dynamic>;
        final code = row['c'] as String?;
        if (code == null) continue;
        // z: 成交價（'-' 代表還沒成交，改用昨收 y）；y: 昨收。
        final zStr = row['z'] as String?;
        final yStr = row['y'] as String?;
        final price = double.tryParse((zStr == '-' ? null : zStr) ?? yStr ?? '');
        final prevClose = double.tryParse(yStr ?? '');
        if (price == null) continue;
        final change = prevClose == null ? 0.0 : price - prevClose;
        out[code] = PriceResult(code, price, change);
      }
      return out;
    } catch (_) {
      // 沒有網路、逾時、證交所格式變了……都當作「這次抓不到」，讓呼叫端保留舊資料。
      return {};
    }
  }

  /// 證交所官方的「每日收盤行情」公開資料（含個股和 ETF），一次回傳當天所有
  /// 上市證券。只在即時來源查不到某支股票時才當備援抓，不是每次都抓整包。
  Future<Map<String, PriceResult>> _fetchDailyCloseFallback(List<String> codes) async {
    final tseCodes = codes.where((c) => kBuiltinStocksByCode[c]?.market != '上櫃').toSet();
    if (tseCodes.isEmpty) return {};
    final uri = Uri.https('openapi.twse.com.tw', '/v1/exchangeReport/STOCK_DAY_ALL');
    try {
      final res = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return {};
      final list = jsonDecode(res.body) as List;
      final out = <String, PriceResult>{};
      for (final raw in list) {
        final row = raw as Map<String, dynamic>;
        final code = row['Code'] as String?;
        if (code == null || !tseCodes.contains(code)) continue;
        final close = _num(row['ClosingPrice']);
        if (close == null) continue;
        out[code] = PriceResult(code, close, _num(row['Change']) ?? 0);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', ''));
  }
}
