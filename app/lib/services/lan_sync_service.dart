/// 區網同步：兩台裝置在同一個 WiFi 底下直接互傳資料，不經過任何雲端
/// 伺服器。做法是其中一台開一個小型本機 HTTP 服務（「分享」），另一台
/// 用瀏覽器看不到的驗證碼連過去拉資料或送資料過去。
///
/// 傳輸的內容就是「匯出全部群體備份」那包 JSON（見 AppRepository.
/// exportAllGroups/importAllGroups），只是用網路請求取代存成檔案。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

class LanSyncServer {
  HttpServer? _server;
  String? pin;
  int? port;

  bool get isRunning => _server != null;

  /// 啟動本機 HTTP 服務（port 由系統自動挑一個沒用到的），回傳監聽的
  /// port。[onExport] 收到拉資料的請求時呼叫，要回傳目前全部群體的資料；
  /// [onImport] 收到送資料過來的請求時呼叫。
  Future<int> start({
    required Future<Map<String, dynamic>> Function() onExport,
    required Future<void> Function(Map<String, dynamic>) onImport,
  }) async {
    pin = (Random.secure().nextInt(9000) + 1000).toString();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    port = server.port;
    server.listen((req) async {
      req.response.headers.contentType = ContentType.json;
      try {
        final givenPin = req.uri.queryParameters['pin'];
        if (givenPin == null || givenPin != pin) {
          req.response.statusCode = 403;
          req.response.write(jsonEncode({'error': '驗證碼不對'}));
          await req.response.close();
          return;
        }
        if (req.method == 'GET' && req.uri.path == '/export') {
          final data = await onExport();
          req.response.write(jsonEncode(data));
        } else if (req.method == 'POST' && req.uri.path == '/import') {
          final body = await utf8.decoder.bind(req).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          await onImport(json);
          req.response.write(jsonEncode({'ok': true}));
        } else {
          req.response.statusCode = 404;
          req.response.write(jsonEncode({'error': 'not found'}));
        }
      } catch (e) {
        req.response.statusCode = 500;
        req.response.write(jsonEncode({'error': e.toString()}));
      }
      await req.response.close();
    });
    return port!;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    pin = null;
    port = null;
  }

  /// 列出這台裝置目前連著的區網 IPv4 位址，給使用者挑一個告訴另一台裝置
  /// （一台裝置可能同時連著好幾個網路介面，所以是清單不是單一位址）。
  static Future<List<String>> localAddresses() async {
    final list = <String>[];
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final i in interfaces) {
      for (final a in i.addresses) {
        if (!a.isLoopback) list.add(a.address);
      }
    }
    return list;
  }
}

class LanSyncClient {
  Future<Map<String, dynamic>> pull({
    required String host,
    required int port,
    required String pin,
  }) async {
    final uri = Uri.http('$host:$port', '/export', {'pin': pin});
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> push({
    required String host,
    required int port,
    required String pin,
    required Map<String, dynamic> data,
  }) async {
    final uri = Uri.http('$host:$port', '/import', {'pin': pin});
    final res = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(data))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception(_errorMessage(res));
    }
  }

  String _errorMessage(http.Response res) {
    if (res.statusCode == 403) return '驗證碼不對';
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['error']?.toString() ?? '連線失敗（${res.statusCode}）';
    } catch (_) {
      return '連線失敗（${res.statusCode}）';
    }
  }
}
