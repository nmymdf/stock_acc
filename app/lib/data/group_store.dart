/// 「群體」是完全獨立的一份資料（戶名、帳戶、交易、關注清單……全部都不共用）。
/// 這個檔案定義群體的清單本身（哪些群體、目前在哪一個），跟每個群體實際的
/// 記帳資料（AppData）是分開存放的——切換群體就是換讀另一個檔案，不會把
/// 兩邊的資料混在一起算。
library;

class GroupInfo {
  final String id;
  String name;
  final DateTime createdAt;

  GroupInfo({required this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GroupInfo.fromJson(Map<String, dynamic> j) => GroupInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class GroupRegistry {
  List<GroupInfo> groups;
  String activeId;

  GroupRegistry({required this.groups, required this.activeId});

  Map<String, dynamic> toJson() => {
        'groups': groups.map((g) => g.toJson()).toList(),
        'activeId': activeId,
      };

  factory GroupRegistry.fromJson(Map<String, dynamic> j) => GroupRegistry(
        groups: (j['groups'] as List)
            .map((e) => GroupInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        activeId: j['activeId'] as String,
      );
}
