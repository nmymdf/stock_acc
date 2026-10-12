import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/services/lan_sync_service.dart';

void main() {
  test('伺服器啟動後，用對的驗證碼可以拉到 onExport 回傳的資料', () async {
    final server = LanSyncServer();
    final port = await server.start(
      onExport: () async => {'hello': 'world'},
      onImport: (_) async {},
    );
    addTearDown(() => server.stop());

    final client = LanSyncClient();
    final data = await client.pull(host: '127.0.0.1', port: port, pin: server.pin!);
    expect(data, {'hello': 'world'});
  });

  test('驗證碼不對會被拒絕（403），不會拿到資料', () async {
    final server = LanSyncServer();
    final port = await server.start(
      onExport: () async => {'secret': 'data'},
      onImport: (_) async {},
    );
    addTearDown(() => server.stop());

    final client = LanSyncClient();
    expect(
      () => client.pull(host: '127.0.0.1', port: port, pin: '0000'),
      throwsA(isA<Exception>()),
    );
  });

  test('push 送過去的資料會被 onImport 收到', () async {
    Map<String, dynamic>? received;
    final server = LanSyncServer();
    final port = await server.start(
      onExport: () async => {},
      onImport: (json) async => received = json,
    );
    addTearDown(() => server.stop());

    final client = LanSyncClient();
    await client.push(host: '127.0.0.1', port: port, pin: server.pin!, data: {'foo': 1});
    expect(received, {'foo': 1});
  });

  test('stop 之後再連線會失敗', () async {
    final server = LanSyncServer();
    final port = await server.start(onExport: () async => {}, onImport: (_) async {});
    final pin = server.pin!;
    await server.stop();

    final client = LanSyncClient();
    expect(
      () => client.pull(host: '127.0.0.1', port: port, pin: pin),
      throwsA(anything),
    );
  });
}
