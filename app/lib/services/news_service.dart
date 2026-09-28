/// 抓 Google 新聞（RSS）搜尋某支股票的新聞，並把同一則被多家媒體轉載的
/// 新聞合併成一則。
///
/// 合併是用「標題去掉標點、空白、來源尾巴後是否相同或互相包含」判斷，
/// 抓得到明顯的轉載，抓不到各家自己改寫標題的同一則新聞——這是簡化過的
/// 版本，畫面上會註明合併方式，使用者也可以在設定裡整個關掉合併。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class NewsItem {
  final String title;
  final String source;
  final String link;
  final DateTime published;

  const NewsItem({
    required this.title,
    required this.source,
    required this.link,
    required this.published,
  });
}

/// 合併後的一則新聞：可能對應好幾篇原始報導（同題材、不同來源）。
class NewsCluster {
  final String title;
  final List<NewsItem> items;

  NewsCluster(this.title, this.items);

  List<String> get sources => {for (final i in items) i.source}.toList();
  DateTime get latest =>
      items.map((i) => i.published).reduce((a, b) => a.isAfter(b) ? a : b);
  NewsItem get primary =>
      items.reduce((a, b) => a.published.isAfter(b.published) ? a : b);
}

class NewsService {
  /// 查一支股票的新聞。[query] 建議用「股票名稱 代號」，比單查代號準。
  /// 抓失敗（沒有網路、逾時）回傳空清單，不丟例外——呼叫端顯示「抓不到新聞」即可。
  Future<List<NewsItem>> fetchNews(String query, {int days = 7}) async {
    final uri = Uri.https('news.google.com', '/rss/search', {
      'q': query,
      'hl': 'zh-TW',
      'gl': 'TW',
      'ceid': 'TW:zh-Hant',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final items = _parseRssItems(utf8.decode(res.bodyBytes));
      final cutoff = DateTime.now().subtract(Duration(days: days));
      return items.where((i) => i.published.isAfter(cutoff)).toList()
        ..sort((a, b) => b.published.compareTo(a.published));
    } catch (_) {
      return [];
    }
  }

  /// 簡單的 RSS `<item>` 解析，只取用得到的 4 個欄位，不依賴額外的 XML 套件。
  List<NewsItem> _parseRssItems(String xml) {
    final items = <NewsItem>[];
    for (final m in RegExp(r'<item>(.*?)</item>', dotAll: true).allMatches(xml)) {
      final block = m.group(1)!;
      final rawTitle = _tag(block, 'title');
      if (rawTitle == null) continue;
      final link = _tag(block, 'link') ?? '';
      final pubDateStr = _tag(block, 'pubDate');
      final date = pubDateStr == null ? null : _tryParseRfc1123(pubDateStr);
      // Google 新聞的標題格式是「標題 - 來源」，來源另外用 <source> 標籤也有，優先用它。
      final sourceTag = _tag(block, 'source');
      final title = sourceTag != null && rawTitle.endsWith(sourceTag)
          ? rawTitle.substring(0, rawTitle.length - sourceTag.length).trim().replaceAll(RegExp(r'[-\s]+$'), '')
          : rawTitle;
      items.add(NewsItem(
        title: _unescape(title),
        source: _unescape(sourceTag ?? '未知來源'),
        link: link,
        published: date ?? DateTime.now(),
      ));
    }
    return items;
  }

  String? _tag(String block, String name) {
    final m = RegExp('<$name[^>]*>(.*?)</$name>', dotAll: true).firstMatch(block);
    return m?.group(1)?.trim();
  }

  String _unescape(String s) => s
      .replaceAll('<![CDATA[', '')
      .replaceAll(']]>', '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();

  DateTime? _tryParseRfc1123(String s) {
    try {
      return HttpDateFormat.parse(s);
    } catch (_) {
      return null;
    }
  }
}

/// 把新聞依標題相似度合併成 [NewsCluster]，同題材、不同來源只顯示一則。
List<NewsCluster> clusterNews(List<NewsItem> items, {required bool merge}) {
  if (!merge) {
    return items.map((i) => NewsCluster(i.title, [i])).toList();
  }
  final clusters = <NewsCluster>[];
  for (final item in items) {
    final key = _normalize(item.title);
    NewsCluster? match;
    for (final c in clusters) {
      final ck = _normalize(c.title);
      if (ck == key || ck.contains(key) || key.contains(ck)) {
        match = c;
        break;
      }
    }
    if (match != null) {
      match.items.add(item);
    } else {
      clusters.add(NewsCluster(item.title, [item]));
    }
  }
  clusters.sort((a, b) => b.latest.compareTo(a.latest));
  return clusters;
}

String _normalize(String s) =>
    s.replaceAll(RegExp(r'[\s，,。.、！!？?「」『』（）()\-—:：]'), '').toLowerCase();

/// 極簡的 RFC 1123 日期解析（RSS pubDate 格式），例如
/// "Fri, 25 Sep 2026 03:00:00 GMT"。避免多加一個日期套件依賴。
class HttpDateFormat {
  static final _months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  static DateTime parse(String s) {
    final m = RegExp(r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})')
        .firstMatch(s);
    if (m == null) throw FormatException('無法解析日期：$s');
    final day = int.parse(m.group(1)!);
    final month = _months[m.group(2)]!;
    final year = int.parse(m.group(3)!);
    final hour = int.parse(m.group(4)!);
    final minute = int.parse(m.group(5)!);
    final second = int.parse(m.group(6)!);
    return DateTime.utc(year, month, day, hour, minute, second).toLocal();
  }
}
