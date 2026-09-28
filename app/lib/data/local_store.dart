/// 存檔的實際讀寫：一個 JSON 檔案，放在系統的「應用程式資料」資料夾。
/// Windows、Linux、Android 都用同一套 `path_provider` API，不用分平台寫。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStore {
  static const _fileName = 'stock_acc_data.json';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/$_fileName');
  }

  /// 讀存檔內容。沒有存檔（第一次開啟）回傳 null。
  Future<Map<String, dynamic>?> read() async {
    final f = await _file();
    if (!await f.exists()) return null;
    final text = await f.readAsString();
    if (text.trim().isEmpty) return null;
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> write(Map<String, dynamic> json) async {
    final f = await _file();
    const encoder = JsonEncoder.withIndent('  ');
    await f.writeAsString(encoder.convert(json));
  }
}
