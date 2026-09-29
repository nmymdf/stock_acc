import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('匯出全部群體後在另一台「全新裝置」匯入，兩個群體都要建立出來', () async {
    final source = AppRepository();
    await source.load();
    await source.addPerson('本人');
    final other = await source.addGroup('幫朋友代操');
    await source.addPerson('朋友');
    expect(source.groups.length, 2);

    final backup = await source.exportAllGroups();

    // 換一個全新的資料夾，模擬全新裝置（沒有任何資料）。
    final freshDir = await Directory.systemTemp.createTemp('stock_acc_test_fresh_');
    addTearDown(() async {
      if (await freshDir.exists()) await freshDir.delete(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => freshDir.path,
    );

    final target = AppRepository();
    await target.load();
    expect(target.groups.length, 1); // 全新安裝只有自動建立的「預設」

    await target.importAllGroups(backup);

    expect(target.groups.length, 3); // 原本的「預設」+ 匯入的兩個群體
    final names = target.groups.map((g) => g.name).toSet();
    expect(names, containsAll(['預設', '幫朋友代操']));

    // 匯入完會切到備份原本使用中的那個群體（幫朋友代操），資料要正確帶過去。
    expect(target.activeGroupId, other.id);
    expect(target.persons.map((p) => p.name), contains('朋友'));
    expect(target.persons.map((p) => p.name), isNot(contains('本人')));

    // 切回另一個匯入進來的群體，資料也要正確隔離（不會混到「幫朋友代操」的人）。
    final defaultGroupFromBackup = target.groups.firstWhere((g) => g.name == '預設' && g.id != target.groups.first.id);
    await target.switchGroup(defaultGroupFromBackup.id);
    expect(target.persons.map((p) => p.name), contains('本人'));
    expect(target.persons.map((p) => p.name), isNot(contains('朋友')));
  });
}
