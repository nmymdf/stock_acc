import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/services/news_service.dart';

NewsItem _item(String title, String source, {int hoursAgo = 0}) => NewsItem(
      title: title,
      source: source,
      link: 'https://example.com/$source',
      published: DateTime.now().subtract(Duration(hours: hoursAgo)),
    );

void main() {
  group('clusterNews', () {
    test('標題幾乎一樣的轉載會合併成一則', () {
      final items = [
        _item('台積電法說會釋利多', '經濟日報', hoursAgo: 1),
        _item('台積電法說會釋利多', 'Yahoo奇摩', hoursAgo: 2),
        _item('台積電法說會釋利多', 'LINE TODAY', hoursAgo: 3),
      ];
      final clusters = clusterNews(items, merge: true);
      expect(clusters.length, 1);
      expect(clusters.first.sources.length, 3);
    });

    test('標題不同的新聞不會被合併', () {
      final items = [
        _item('台積電法說會釋利多', '經濟日報'),
        _item('鴻海宣布擴大投資', '工商時報'),
      ];
      final clusters = clusterNews(items, merge: true);
      expect(clusters.length, 2);
    });

    test('關掉合併時，每篇報導都各自顯示', () {
      final items = [
        _item('台積電法說會釋利多', '經濟日報'),
        _item('台積電法說會釋利多', 'Yahoo奇摩'),
      ];
      final clusters = clusterNews(items, merge: false);
      expect(clusters.length, 2);
    });

    test('合併後顯示最新一篇的時間', () {
      final items = [
        _item('台積電法說會釋利多', '經濟日報', hoursAgo: 5),
        _item('台積電法說會釋利多', 'Yahoo奇摩', hoursAgo: 1),
      ];
      final clusters = clusterNews(items, merge: true);
      expect(clusters.first.primary.source, 'Yahoo奇摩');
    });
  });
}
