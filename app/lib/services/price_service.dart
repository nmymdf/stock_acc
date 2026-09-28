/// 抓證交所的即時股價（基本市況報導 API）。免費、不用帳號，
/// 但不是正式公開的 API，格式偶爾可能會變，抓失敗時要能安靜地失敗。
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
      final part = await _fetchBatch(batch);
      result.addAll(part);
    }
    return result;
  }

  Future<Map<String, PriceResult>> _fetchBatch(List<String> codes) async {
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
}
