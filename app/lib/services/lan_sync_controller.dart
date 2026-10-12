/// 區網同步的畫面狀態：包著 [LanSyncServer]/[LanSyncClient]，讓「分享中」
/// 這個狀態在切換分頁時不會被重置（跟 NewsCache 一樣掛在 app 最上層）。
library;

import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import 'lan_sync_service.dart';

class LanSyncController extends ChangeNotifier {
  final _server = LanSyncServer();
  final _client = LanSyncClient();

  bool get isSharing => _server.isRunning;
  String? get pin => _server.pin;
  int? get port => _server.port;
  List<String> addresses = [];
  String? error;
  bool busy = false;

  Future<void> startSharing(AppRepository repo) async {
    error = null;
    busy = true;
    notifyListeners();
    try {
      addresses = await LanSyncServer.localAddresses();
      await _server.start(
        onExport: () => repo.exportAllGroups(),
        onImport: (json) => repo.importAllGroups(json),
      );
    } catch (e) {
      error = '啟動失敗：$e';
    }
    busy = false;
    notifyListeners();
  }

  Future<void> stopSharing() async {
    await _server.stop();
    notifyListeners();
  }

  /// 從另一台裝置拉資料下來匯入到這台。
  Future<void> pullFrom(
    AppRepository repo, {
    required String host,
    required int port,
    required String pin,
  }) async {
    final data = await _client.pull(host: host, port: port, pin: pin);
    await repo.importAllGroups(data);
  }

  /// 把這台裝置的資料送到另一台（另一台要是正在「分享」的那一台）。
  Future<void> pushTo(
    AppRepository repo, {
    required String host,
    required int port,
    required String pin,
  }) async {
    final data = await repo.exportAllGroups();
    await _client.push(host: host, port: port, pin: pin, data: data);
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }
}
