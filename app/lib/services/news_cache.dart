/// 新聞抓回來之後先快取在記憶體裡，同一支股票在這次開 App 期間
/// 不用每次切換畫面都重抓。「資訊」頁的更新按鈕、期間選單改變時
/// 才會真的重新呼叫 [NewsService]。
library;

import 'package:flutter/foundation.dart';

import 'news_service.dart';

class NewsCache extends ChangeNotifier {
  final NewsService _service = NewsService();
  final Map<String, List<NewsItem>> _byCode = {};
  final Set<String> _loading = {};
  DateTime? lastUpdated;

  List<NewsItem>? itemsFor(String code) => _byCode[code];
  bool isLoading(String code) => _loading.contains(code);
  bool hasFetched(String code) => _byCode.containsKey(code);

  Future<void> ensure(String code, {String name = '', int days = 7, bool force = false}) async {
    if (!force && _byCode.containsKey(code)) return;
    _loading.add(code);
    notifyListeners();
    final query = name.isEmpty ? code : '$name $code';
    final items = await _service.fetchNews(query, days: days);
    _byCode[code] = items;
    _loading.remove(code);
    lastUpdated = DateTime.now();
    notifyListeners();
  }

  Future<void> refreshAll(List<String> codes, Map<String, String> names, {int days = 7}) async {
    await Future.wait(codes.map((c) => ensure(c, name: names[c] ?? '', days: days, force: true)));
  }
}
