/// 存檔的實際讀寫：JSON 檔案，放在系統的「應用程式資料」資料夾。
/// Windows、Linux、Android 都用同一套 `path_provider` API，不用分平台寫。
///
/// 群體清單存在固定檔名 [groupsFileName]；每個群體自己的記帳資料另外存成
/// 一個檔案，檔名依群體的 id 而定（見 [dataFileNameFor]），切換群體就是
/// 換讀寫不同的檔案。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStore {
  static const groupsFileName = 'stock_acc_groups.json';

  /// 舊版（還沒有「群體」概念之前）唯一的一份存檔，第一次升級時要讀出來
  /// 搬進新格式，之後不會再寫入這個檔名。
  static const legacyFileName = 'stock_acc_data.json';

  static String dataFileNameFor(String groupId) => 'stock_acc_data_$groupId.json';

  Future<Directory> _dir() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Map<String, dynamic>?> readNamed(String fileName) async {
    final dir = await _dir();
    final f = File('${dir.path}/$fileName');
    if (!await f.exists()) return null;
    final text = await f.readAsString();
    if (text.trim().isEmpty) return null;
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> writeNamed(String fileName, Map<String, dynamic> json) async {
    final dir = await _dir();
    final f = File('${dir.path}/$fileName');
    const encoder = JsonEncoder.withIndent('  ');
    await f.writeAsString(encoder.convert(json));
  }

  Future<void> deleteNamed(String fileName) async {
    final dir = await _dir();
    final f = File('${dir.path}/$fileName');
    if (await f.exists()) await f.delete();
  }
}
