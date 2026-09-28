/// 共用的小元件：統計卡片、清單列、區塊標題。畫面上大部分「一列資料」
/// 都是用 [InfoRow] 拼出來的，維持跟草稿一致的緊湊列表風格。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shell.dart';

/// 群體/個人合計用的深色卡片，對應草稿的 `.hero`。
class HeroTotalsCard extends StatelessWidget {
  final String label;
  final String big;
  final List<(String, String, Color?)> stats;

  const HeroTotalsCard({
    super.key,
    required this.label,
    required this.big,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: scheme.onPrimary.withValues(alpha: .8), fontSize: 12)),
          const SizedBox(height: 2),
          Text(big,
              style: TextStyle(
                  color: scheme.onPrimary, fontSize: 26, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              for (final s in stats)
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1, style: TextStyle(color: scheme.onPrimary.withValues(alpha: .78), fontSize: 12)),
                      Text(s.$2,
                          style: TextStyle(
                              color: s.$3 ?? scheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 小型統計數字方格（例如個股頁「總股數、均價、成本…」那排）。
class StatGrid extends StatelessWidget {
  final List<(String, String, Color?)> stats;
  final int columns;

  const StatGrid({super.key, required this.stats, this.columns = 3});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final s in stats)
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.$1, style: Theme.of(context).textTheme.bodySmall),
                    Text(s.$2,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: s.$3,
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 區塊標題列，例如「持有中 7 檔」左邊標題、右邊補充說明。
class SectionHeader extends StatelessWidget {
  final String left;
  final String? right;
  final Widget? trailing;

  const SectionHeader({super.key, required this.left, this.right, this.trailing});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 2),
      child: Row(
        children: [
          Expanded(child: Text(left, style: style)),
          if (trailing != null) trailing!,
          if (right != null) Text(right!, style: style),
        ],
      ),
    );
  }
}

/// 一張卡片包住一組 [InfoRow]，中間有分隔線，對應草稿的 `.list`。
class RowList extends StatelessWidget {
  final List<Widget> children;
  final String emptyText;

  const RowList({super.key, required this.children, this.emptyText = '沒有資料'});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(emptyText, style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 清單裡的一列：左上標題、左下副標、右上主要數字、右下次要數字。
/// 各欄位都可省略，用來拼出股票列、交易列、人員列等各種列表。
class InfoRow extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailingTop;
  final Widget? trailingBottom;
  final bool selected;

  const InfoRow({
    super.key,
    this.onTap,
    required this.title,
    this.subtitle,
    this.trailingTop,
    this.trailingBottom,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? scheme.primaryContainer.withValues(alpha: .5) : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    child: title,
                  ),
                  if (subtitle != null)
                    DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      child: subtitle!,
                    ),
                ],
              ),
            ),
            if (trailingTop != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 14),
                    child: trailingTop!,
                  ),
                  if (trailingBottom != null)
                    DefaultTextStyle.merge(
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      child: trailingBottom!,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 小標籤徽章：買 / 賣。
class SideBadge extends StatelessWidget {
  final bool isBuy;
  const SideBadge({super.key, required this.isBuy});

  @override
  Widget build(BuildContext context) {
    final color = isBuy
        ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF6D60) : const Color(0xFFCF3528))
        : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4CC47F) : const Color(0xFF17824A));
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(isBuy ? '買' : '賣',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

/// 明細畫面（個股、個人、新聞列表、交易表單、查詢）共用的頂端列。
/// 寬螢幕時按返回會收起右邊窗格；窄螢幕（換頁）時按返回會回上一頁——
/// 用「目前有沒有頁面可以 pop」判斷是哪一種情況，兩邊共用同一顆按鈕。
class DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget> actions;

  const DetailAppBar({super.key, required this.title, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回',
        onPressed: () {
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
          } else {
            context.read<ShellController>().closeDetail();
          }
        },
      ),
    );
  }
}

/// 通用的空狀態提示，用在右邊明細窗格還沒選任何項目時。
class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.crop_square, size: 34, color: scheme.onSurfaceVariant.withValues(alpha: .5)),
            const SizedBox(height: 10),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
