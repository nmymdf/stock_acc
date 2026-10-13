/// 區網同步的畫面狀態：包著 [LanSyncServer]/[LanSyncClient]，讓「分享中」
/// 這個狀態在切換分頁時不會被重置（跟 NewsCache 一樣掛在 app 最上層）。
library;

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/repository.dart';
import 'lan_sync_service.dart';

class LanSyncController extends ChangeNotifier {
  final _server = LanSyncServer();
  final _client = LanSyncClient();
  final _store = LocalStore();

  bool get isSharing => _server.isRunning;
  String? get pin => _server.pin;
  int? get port => _server.port;
  List<String> addresses = [];
  String? error;
  bool busy = false;

  /// 上次連線成功的位址/埠號，連線對話框打開時拿來預先填好，不用每次
  /// 都重打一次（驗證碼每次分享都會換新的，沒辦法記，還是要重打）。
  String? lastHost;
  int? lastPort;

  Future<void> loadLastTarget() async {
    final json = await _store.readNamed(LocalStore.lanSyncPrefsFileName);
    if (json == null) return;
    lastHost = json['host'] as String?;
    lastPort = json['port'] as int?;
    notifyListeners();
  }

  Future<void> _saveLastTarget(String host, int port) async {
    lastHost = host;
    lastPort = port;
    await _store.writeNamed(LocalStore.lanSyncPrefsFileName, {'host': host, 'port': port});
  }

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
    await _saveLastTarget(host, port);
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
    await _saveLastTarget(host, port);
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }
}
