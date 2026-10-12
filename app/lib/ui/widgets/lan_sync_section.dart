/// 設定頁「區網同步」區塊：不透過雲端，兩台裝置在同一個 WiFi 底下
/// 直接互傳資料。一台「分享」（當伺服器），另一台輸入位址/驗證碼
/// 連過去拉或送資料。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../services/lan_sync_controller.dart';

class LanSyncSection extends StatelessWidget {
  const LanSyncSection({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<LanSyncController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            '兩台裝置要在同一個 WiFi 底下才能互傳；不經過任何雲端伺服器。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (!sync.isSharing) ...[
            FilledButton.tonalIcon(
              onPressed: sync.busy ? null : () => sync.startSharing(context.read<AppRepository>()),
              icon: sync.busy
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering, size: 18),
              label: const Text('開始分享這台的資料（當伺服器）'),
            ),
            if (sync.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(sync.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('在另一台裝置輸入：', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                for (final addr in sync.addresses)
                  SelectableText('位址：$addr　埠號：${sync.port}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (sync.addresses.isEmpty)
                  const Text('（找不到區網位址，確認這台裝置有連 WiFi／網路線）', style: TextStyle(fontSize: 12, color: Colors.red)),
                const SizedBox(height: 4),
                SelectableText('驗證碼：${sync.pin}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => sync.stopSharing(),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('停止分享'),
            ),
          ],
          const Divider(height: 28),
          OutlinedButton.icon(
            onPressed: () => _connectDialog(context, sync),
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('連線到另一台裝置'),
          ),
        ]),
      ),
    );
  }

  Future<void> _connectDialog(BuildContext context, LanSyncController sync) async {
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final repo = context.read<AppRepository>();
    bool busy = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setLocalState) => AlertDialog(
              title: const Text('連線到另一台裝置'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: '對方顯示的位址（例如 192.168.1.23）')),
                const SizedBox(height: 10),
                TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(labelText: '埠號'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinCtrl,
                  decoration: const InputDecoration(labelText: '驗證碼'),
                  keyboardType: TextInputType.number,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                if (busy) const Padding(padding: EdgeInsets.only(top: 10), child: CircularProgressIndicator()),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await _confirm(dialogContext, '把這台的資料送過去？', '會覆蓋對方同一個群體 id 的資料，無法復原。');
                          if (ok != true) return;
                          setLocalState(() => busy = true);
                          try {
                            await sync.pushTo(repo,
                                host: hostCtrl.text.trim(),
                                port: int.parse(portCtrl.text.trim()),
                                pin: pinCtrl.text.trim());
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已把這台的資料送過去')));
                            }
                          } catch (e) {
                            setLocalState(() {
                              busy = false;
                              error = '$e';
                            });
                          }
                        },
                  child: const Text('送過去'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await _confirm(dialogContext, '從對方拉資料？', '會覆蓋這台同一個群體 id 的資料，無法復原。');
                          if (ok != true) return;
                          setLocalState(() => busy = true);
                          try {
                            await sync.pullFrom(repo,
                                host: hostCtrl.text.trim(),
                                port: int.parse(portCtrl.text.trim()),
                                pin: pinCtrl.text.trim());
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已拉取資料並匯入')));
                            }
                          } catch (e) {
                            setLocalState(() {
                              busy = false;
                              error = '$e';
                            });
                          }
                        },
                  child: const Text('拉過來'),
                ),
              ],
            ),
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, String title, String content) => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('確定')),
          ],
        ),
      );
}
