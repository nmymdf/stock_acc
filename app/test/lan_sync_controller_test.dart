import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/data/repository.dart';
import 'package:stock_acc/services/lan_sync_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // TestWidgetsFlutterBinding 預設會攔截所有 HttpClient 請求、一律回傳
  // 400，這個測試真的要開本機 socket 收送資料，所以關掉這個攔截。
  HttpOverrides.global = null;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stock_acc_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('連線成功一次後，位址/埠號會記住，下次開控制器能讀回來', () async {
    final a = LanSyncController();
    await a.loadLastTarget();
    expect(a.lastHost, isNull);

    final repoA = AppRepository();
    await repoA.load();
    final server = a; // 自己當分享端
    await server.startSharing(repoA);
    addTearDown(() => server.stopSharing());

    final client = LanSyncController();
    await client.loadLastTarget();
    final repoB = AppRepository();
    await repoB.load();
    await client.pullFrom(repoB, host: '127.0.0.1', port: server.port!, pin: server.pin!);

    expect(client.lastHost, '127.0.0.1');
    expect(client.lastPort, server.port);

    // 模擬下次打開 App：重新建一個控制器，讀出來的應該是上次存的值。
    final reopened = LanSyncController();
    await reopened.loadLastTarget();
    expect(reopened.lastHost, '127.0.0.1');
    expect(reopened.lastPort, server.port);
  });
}
