/// 「裝置同步」入口：總覽頁 AppBar 上的按鈕，跟「更新股價」（抓股價）
/// 分開，這個是手機/電腦互傳記帳資料用的（區網同步，不經過雲端）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shell.dart';
import 'common.dart';
import 'lan_sync_section.dart';

class DeviceSyncButton extends StatelessWidget {
  const DeviceSyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.read<ShellController>().open(context, const SyncRoute()),
      icon: const Icon(Icons.sync, size: 18),
      label: const Text('裝置同步'),
    );
  }
}

class DeviceSyncDetail extends StatelessWidget {
  const DeviceSyncDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DetailAppBar(title: Text('裝置同步')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [LanSyncSection()],
      ),
    );
  }
}
