import 'package:flutter_test/flutter_test.dart';
import 'package:stock_acc/data/group_store.dart';

void main() {
  test('GroupRegistry 序列化來回不失真', () {
    final now = DateTime.now();
    final reg = GroupRegistry(
      groups: [
        GroupInfo(id: 'a', name: '預設', createdAt: now),
        GroupInfo(id: 'b', name: '幫朋友代操', createdAt: now),
      ],
      activeId: 'b',
    );
    final back = GroupRegistry.fromJson(reg.toJson());
    expect(back.activeId, 'b');
    expect(back.groups.map((g) => g.name), ['預設', '幫朋友代操']);
    expect(back.groups.map((g) => g.id), ['a', 'b']);
  });
}
