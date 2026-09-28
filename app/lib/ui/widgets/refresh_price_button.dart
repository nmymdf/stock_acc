/// 「更新股價」按鈕：抓目前有交易或關注的股票現價，寫回本機存檔。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../services/price_service.dart';

class RefreshPriceButton extends StatefulWidget {
  final String label;
  const RefreshPriceButton({super.key, this.label = '更新股價'});

  @override
  State<RefreshPriceButton> createState() => _RefreshPriceButtonState();
}

class _RefreshPriceButtonState extends State<RefreshPriceButton> {
  bool _loading = false;
  final _service = PriceService();

  Future<void> _refresh() async {
    final repo = context.read<AppRepository>();
    final codes = {...repo.tradedCodes, ...repo.watchlist}.toList();
    if (codes.isEmpty) return;
    setState(() => _loading = true);
    try {
      final result = await _service.fetchQuotes(codes);
      if (result.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('抓不到股價，請檢查網路連線')),
          );
        }
        return;
      }
      await repo.setQuotes({
        for (final e in result.entries) e.key: (price: e.value.price, change: e.value.change),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已更新 ${result.length} 檔股價')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _loading ? null : _refresh,
      icon: _loading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh, size: 18),
      label: Text(widget.label),
    );
  }
}
