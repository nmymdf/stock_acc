/// 設定頁：人和券商帳戶管理、合併新聞開關、備份匯出匯入。
library;

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/group_store.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const SectionHeader(left: '群體', right: '完全獨立的資料，互不相通'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final g in repo.groups) ...[
                if (g != repo.groups.first) const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    g.id == repo.activeGroupId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: g.id == repo.activeGroupId ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(g.name, style: TextStyle(fontWeight: g.id == repo.activeGroupId ? FontWeight.w700 : FontWeight.w400)),
                  subtitle: g.id == repo.activeGroupId ? const Text('目前使用中') : null,
                  onTap: g.id == repo.activeGroupId ? null : () => repo.switchGroup(g.id),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') _renameGroupDialog(context, repo, g);
                      if (v == 'delete') _confirmDeleteGroup(context, repo, g);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('修改群體名稱')),
                      PopupMenuItem(
                        value: 'delete',
                        enabled: repo.groups.length > 1,
                        child: const Text('刪除這個群體'),
                      ),
                    ],
                  ),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.add, color: Colors.teal),
                title: const Text('新增群體', style: TextStyle(color: Colors.teal)),
                onTap: () => _addGroupDialog(context, repo),
              ),
            ]),
          ),
          const SectionHeader(left: '戶名與券商帳戶'),
          for (final p in repo.persons)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(children: [
                ListTile(
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') _renamePersonDialog(context, repo, p.id, p.name);
                      if (v == 'delete') _confirmDeletePerson(context, repo, p.id, p.name);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('修改戶名')),
                      PopupMenuItem(value: 'delete', child: Text('刪除這個戶名')),
                    ],
                  ),
                ),
                for (final a in repo.accountsOf(p.id))
                  ListTile(
                    dense: true,
                    title: Text('　${a.broker}'),
                    trailing: TextButton(
                      onPressed: () => _accountDialog(context, repo, personId: p.id, account: a),
                      child: Text('手續費 ${a.discount} 折 ›'),
                    ),
                  ),
                ListTile(
                  dense: true,
                  title: const Text('　＋ 新增券商帳戶', style: TextStyle(color: Colors.teal)),
                  onTap: () => _accountDialog(context, repo, personId: p.id),
                ),
              ]),
            ),
          FilledButton.tonal(
            onPressed: () => _addPersonDialog(context, repo),
            child: const Text('＋ 新增戶名'),
          ),
          const SectionHeader(left: '新聞'),
          Card(
            child: SwitchListTile(
              title: const Text('合併相同新聞'),
              value: repo.mergeNews,
              onChanged: (v) => repo.setMergeNews(v),
            ),
          ),
          const SectionHeader(left: '資料（只存在這台裝置，不上雲端）'),
          Card(
            child: Column(children: [
              ListTile(
                title: const Text('匯出備份（目前這個群體）'),
                subtitle: const Text('只匯出目前群體的資料，換裝置時用來匯入'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportBackup(context, repo),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('匯入備份（目前這個群體）'),
                subtitle: const Text('選擇備份檔，整包取代目前群體的資料'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importBackup(context, repo),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('匯出全部群體備份'),
                subtitle: Text('把全部 ${repo.groups.length} 個群體一次匯出成一個檔案，換裝置時一次匯入'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportAllGroupsBackup(context, repo),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('匯入全部群體備份'),
                subtitle: const Text('選擇「匯出全部群體備份」存的檔案，備份裡的群體都會建立或覆蓋，本機原有、備份裡沒有的群體不受影響'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importAllGroupsBackup(context, repo),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('資料存放的資料夾'),
                subtitle: Text(repo.storageDirPath.isEmpty ? '讀取中…' : repo.storageDirPath),
                trailing: const Icon(Icons.copy, size: 18),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: repo.storageDirPath));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製資料夾路徑')));
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('目前群體清單（除錯用）'),
                subtitle: Text(repo.groups.map((g) => '${g.name}（${g.id.substring(0, 8)}…）').join('\n')),
                trailing: const Icon(Icons.copy, size: 18),
                onTap: () async {
                  final text =
                      '資料夾：${repo.storageDirPath}\n目前群體（${repo.groups.length} 個，使用中：${repo.activeGroupName}）：\n'
                      '${repo.groups.map((g) => '- ${g.name}　${g.id}').join('\n')}';
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製群體清單，貼給我看')));
                  }
                },
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('手續費 = 成交金額 × 0.1425% × 折扣，最低 20 元。賣出交易稅 0.3%。每筆都可以手動改。',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _addGroupDialog(BuildContext context, AppRepository repo) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增群體'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '群體名稱', hintText: '例如：幫朋友代操'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('新增並切換')),
        ],
      ),
    );
    if (name == null) return; // 按了「取消」
    if (name.isEmpty) {
      // 沒打名稱就按「新增並切換」：以前這裡是靜默不做事，使用者會以為
      // 已經新增成功、回頭卻看不到新群體。改成明確告知沒有新增。
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('沒有輸入名稱，沒有新增群體')));
      }
      return;
    }
    await repo.addGroup(name);
  }

  Future<void> _renameGroupDialog(BuildContext context, AppRepository repo, GroupInfo g) async {
    final ctrl = TextEditingController(text: g.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改群體名稱'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: '群體名稱')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('儲存')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await repo.renameGroup(g.id, name);
  }

  Future<void> _confirmDeleteGroup(BuildContext context, AppRepository repo, GroupInfo g) async {
    if (repo.groups.length <= 1) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('刪除群體「${g.name}」？'),
        content: const Text('這個群體裡的所有戶名、帳戶、交易紀錄都會一起刪除，無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );
    if (ok == true) await repo.deleteGroup(g.id);
  }

  Future<void> _addPersonDialog(BuildContext context, AppRepository repo) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增戶名'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: '戶名')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('新增')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await repo.addPerson(name);
  }

  Future<void> _renamePersonDialog(BuildContext context, AppRepository repo, String id, String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改戶名'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: '戶名')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('儲存')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) await repo.renamePerson(id, name);
  }

  Future<void> _confirmDeletePerson(BuildContext context, AppRepository repo, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('刪除「$name」？'),
        content: const Text('這個戶名底下的所有帳戶和交易紀錄也會一起刪除，無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );
    if (ok == true) await repo.removePerson(id);
  }

  Future<void> _accountDialog(BuildContext context, AppRepository repo, {required String personId, BrokerAccount? account}) async {
    final brokerCtrl = TextEditingController(text: account?.broker ?? '');
    final discountCtrl = TextEditingController(text: account == null ? '10' : account.discount.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(account == null ? '新增券商帳戶' : '修改券商帳戶'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: brokerCtrl, decoration: const InputDecoration(labelText: '券商名稱')),
          const SizedBox(height: 10),
          TextField(
            controller: discountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '手續費折扣（10 = 不打折，2.8 = 2.8 折）'),
          ),
        ]),
        actions: [
          if (account != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () async {
                await repo.removeAccount(account.id);
                if (context.mounted) Navigator.pop(context, false);
              },
              child: const Text('刪除'),
            ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('儲存')),
        ],
      ),
    );
    if (result == true) {
      final broker = brokerCtrl.text.trim();
      final discount = double.tryParse(discountCtrl.text) ?? 10;
      if (broker.isEmpty) return;
      if (account == null) {
        await repo.addAccount(personId: personId, broker: broker, discount: discount);
      } else {
        await repo.updateAccount(account.id, broker: broker, discount: discount);
      }
    }
  }

  Future<void> _exportBackup(BuildContext context, AppRepository repo) async {
    final json = const JsonEncoder.withIndent('  ').convert(repo.data.toJson());
    final bytes = utf8.encode(json);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final location = await getSaveLocation(
      suggestedName: 'stock_acc_backup_$stamp.json',
      acceptedTypeGroups: const [XTypeGroup(label: 'JSON', extensions: ['json'])],
    );
    if (location == null) return;
    final file = XFile.fromData(bytes, mimeType: 'application/json', name: 'backup.json');
    await file.saveTo(location.path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已匯出備份')));
    }
  }

  Future<void> _importBackup(BuildContext context, AppRepository repo) async {
    final file = await openFile(
      acceptedTypeGroups: const [XTypeGroup(label: 'JSON', extensions: ['json'])],
    );
    if (file == null) return;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('匯入備份？'),
        content: const Text('會用備份檔整包取代目前的資料，現在的資料會被覆蓋，無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定匯入')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final text = await file.readAsString();
      final json = jsonDecode(text) as Map<String, dynamic>;
      await repo.replaceAll(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已匯入備份')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('這個檔案看起來不是有效的備份檔')));
      }
    }
  }

  Future<void> _exportAllGroupsBackup(BuildContext context, AppRepository repo) async {
    final data = await repo.exportAllGroups();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(json);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final location = await getSaveLocation(
      suggestedName: 'stock_acc_all_groups_$stamp.json',
      acceptedTypeGroups: const [XTypeGroup(label: 'JSON', extensions: ['json'])],
    );
    if (location == null) return;
    final file = XFile.fromData(bytes, mimeType: 'application/json', name: 'backup.json');
    await file.saveTo(location.path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已匯出全部群體備份')));
    }
  }

  Future<void> _importAllGroupsBackup(BuildContext context, AppRepository repo) async {
    final file = await openFile(
      acceptedTypeGroups: const [XTypeGroup(label: 'JSON', extensions: ['json'])],
    );
    if (file == null) return;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('匯入全部群體備份？'),
        content: const Text('備份裡的每個群體都會被建立（本機沒有的話）或覆蓋（本機已經有同一個群體的話），無法復原。本機原有、備份裡沒有的其他群體不受影響。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('確定匯入')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final text = await file.readAsString();
      final json = jsonDecode(text) as Map<String, dynamic>;
      await repo.importAllGroups(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已匯入全部群體備份')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('這個檔案看起來不是有效的「全部群體」備份檔')));
      }
    }
  }
}
