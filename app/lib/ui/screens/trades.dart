/// 交易紀錄列表，以及新增／修改交易的表單。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../data/stock_catalog.dart';
import '../../logic/fees.dart';
import '../../models/models.dart';
import '../format.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';

Widget buildTradeRow(BuildContext context, Trade t, {bool nested = false}) {
  final repo = context.watch<AppRepository>();
  final acc = repo.accountById(t.accountId);
  final person = acc == null ? null : repo.personById(acc.personId);
  return InfoRow(
    onTap: () => context
        .read<ShellController>()
        .open(context, TradeFormRoute(tradeId: t.id), nested: nested),
    title: Row(children: [
      SideBadge(isBuy: t.side == TradeSide.buy),
      Text('${t.code}  ${repo.nameOf(t.code).isEmpty ? t.name : repo.nameOf(t.code)}'),
    ]),
    subtitle: Text(
        '${t.date.month}/${t.date.day.toString().padLeft(2, '0')} · ${person?.name ?? ''}${acc == null ? '' : '-${acc.broker}'}'),
    trailingTop: Text(f0(t.netCashFlow.abs()), style: TextStyle(color: changeColor(context, t.side == TradeSide.buy ? -1 : 1))),
    trailingBottom: Text('${shareTxt(t.shares)} @ ${f2(t.price)}'),
  );
}

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen> {
  String? _personId;
  String? _accountId;
  String? _code;
  String? _month; // yyyy-MM

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final scope = ScopeFilter(personId: _personId, accountId: _accountId);
    final base = repo.trades.where((t) {
      final acc = repo.accountById(t.accountId);
      return acc != null && scope.matches(acc);
    }).toList();
    final codes = ({for (final t in base) t.code}.toList()..sort());
    if (_code != null && !codes.contains(_code)) _code = null;
    final base2 = base.where((t) => _code == null || t.code == _code).toList();
    final months = ({for (final t in base2) _ym(t.date)}.toList()..sort((a, b) => b.compareTo(a)));
    if (_month != null && !months.contains(_month)) _month = null;
    final list = base2.where((t) => _month == null || _ym(t.date) == _month).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final grouped = <String, List<Trade>>{};
    for (final t in list) {
      grouped.putIfAbsent(_ym(t.date), () => []).add(t);
    }
    final accountsForPerson = _personId == null ? repo.data.accounts : repo.accountsOf(_personId!);

    return Scaffold(
      appBar: AppBar(title: const Text('交易紀錄')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<ShellController>().open(context, const TradeFormRoute()),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _personId,
                decoration: const InputDecoration(labelText: '人'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  for (final p in repo.persons) DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() {
                  _personId = v;
                  _accountId = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: '帳戶'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  for (final a in accountsForPerson)
                    DropdownMenuItem(
                        value: a.id,
                        child: Text(_personId == null ? '${repo.personById(a.personId)?.name}-${a.broker}' : a.broker)),
                ],
                onChanged: (v) => setState(() => _accountId = v),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _code,
                decoration: const InputDecoration(labelText: '股票'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  for (final c in codes) DropdownMenuItem(value: c, child: Text('$c ${repo.nameOf(c)}')),
                ],
                onChanged: (v) => setState(() => _code = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _month,
                decoration: const InputDecoration(labelText: '月份（只列有交易的月份）'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  for (final m in months) DropdownMenuItem(value: m, child: Text(monthLabel(m))),
                ],
                onChanged: (v) => setState(() => _month = v),
              ),
            ),
          ]),
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('沒有符合條件的交易')),
          for (final ym in grouped.keys.toList()..sort((a, b) => b.compareTo(a))) ...[
            SectionHeader(left: monthLabel(ym), right: '${grouped[ym]!.length} 筆'),
            RowList(children: [for (final t in grouped[ym]!) buildTradeRow(context, t)]),
          ],
          const SizedBox(height: 72),
        ],
      ),
    );
  }

  String _ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

class TradeFormDetail extends StatefulWidget {
  final String? tradeId;
  final String? presetCode;
  const TradeFormDetail({super.key, this.tradeId, this.presetCode});

  @override
  State<TradeFormDetail> createState() => _TradeFormDetailState();
}

class _TradeFormDetailState extends State<TradeFormDetail> {
  String? _accountId;
  TradeSide _side = TradeSide.buy;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _sharesCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _taxCtrl;
  DateTime _date = DateTime.now();
  bool _feeTouched = false;
  bool _taxTouched = false;
  bool _confirmDelete = false;

  Trade? get _existing =>
      widget.tradeId == null ? null : context.read<AppRepository>().tradeById(widget.tradeId!);

  @override
  void initState() {
    super.initState();
    final t = _existing;
    _accountId = t?.accountId;
    _side = t?.side ?? TradeSide.buy;
    _codeCtrl = TextEditingController(text: t?.code ?? widget.presetCode ?? '');
    _sharesCtrl = TextEditingController(text: t == null ? '' : t.shares.toString());
    _priceCtrl = TextEditingController(text: t == null ? '' : _trimNum(t.price));
    _feeCtrl = TextEditingController(text: t == null ? '0' : t.fee.toString());
    _taxCtrl = TextEditingController(text: t == null ? '0' : t.tax.toString());
    _date = t?.date ?? DateTime.now();
    _feeTouched = t != null; // 修改舊資料時，手續費先當成「原本記錄的金額」，改了才算手動修改
    _taxTouched = t != null;
    for (final c in [_codeCtrl, _sharesCtrl, _priceCtrl]) {
      c.addListener(() => setState(_recalc));
    }
  }

  String _trimNum(double n) => n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();

  double get _amount => (double.tryParse(_sharesCtrl.text) ?? 0) * (double.tryParse(_priceCtrl.text) ?? 0);

  void _recalc() {
    final repo = context.read<AppRepository>();
    final acc = _accountId == null ? null : repo.accountById(_accountId!);
    if (!_feeTouched) {
      _feeCtrl.text = _amount == 0 || acc == null ? '0' : calcFee(_amount, acc.discount).toString();
    }
    if (!_taxTouched) {
      _taxCtrl.text = _amount == 0 ? '0' : calcTax(_side == TradeSide.sell, _amount).toString();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _sharesCtrl.dispose();
    _priceCtrl.dispose();
    _feeCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isEdit = widget.tradeId != null;
    final accounts = repo.data.accounts;
    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _recalc());
    }
    final code = _codeCtrl.text.trim().toUpperCase();
    final info = kBuiltinStocksByCode[code];
    final nameHint = info != null
        ? '${info.name}（${info.market}）'
        : code.isEmpty
            ? '輸入代號自動帶出名稱'
            : (repo.nameOf(code).isNotEmpty ? '${repo.nameOf(code)}（自訂名稱）' : '查無此代號，可以自己輸入名稱');
    final fee = int.tryParse(_feeCtrl.text) ?? 0;
    final tax = int.tryParse(_taxCtrl.text) ?? 0;
    final total = _side == TradeSide.buy ? _amount + fee : _amount - fee - tax;
    final acc = _accountId == null ? null : repo.accountById(_accountId!);

    return Scaffold(
      appBar: DetailAppBar(title: Text(isEdit ? '修改交易' : '新增交易')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: accounts.any((a) => a.id == _accountId) ? _accountId : null,
            decoration: InputDecoration(labelText: '帳戶', helperText: isEdit ? '帳戶不能修改，如果選錯了請刪除重新新增' : null),
            items: [
              for (final a in accounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text('${repo.personById(a.personId)?.name}-${a.broker}（${a.discount} 折）'),
                ),
            ],
            onChanged: isEdit
                ? null
                : (v) => setState(() {
                      _accountId = v;
                      _recalc();
                    }),
          ),
          const SizedBox(height: 12),
          SegmentedButton<TradeSide>(
            segments: const [
              ButtonSegment(value: TradeSide.buy, label: Text('買進')),
              ButtonSegment(value: TradeSide.sell, label: Text('賣出')),
            ],
            selected: {_side},
            onSelectionChanged: (s) => setState(() {
              _side = s.first;
              _recalc();
            }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(labelText: '股票代號'),
                  textCapitalization: TextCapitalization.characters,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(nameHint,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '日期'),
                  child: Text('${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}'),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _sharesCtrl,
                  decoration: const InputDecoration(labelText: '股數'),
                  keyboardType: TextInputType.number,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Text('1 張 = 1000 股', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: '成交價'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _feeCtrl,
                  decoration: const InputDecoration(labelText: '手續費'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _feeTouched = true),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    !_feeTouched && acc != null ? '自動：${acc.discount} 折，最低 20' : (isEdit ? '原本記錄的金額' : '已手動修改'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _taxCtrl,
                  decoration: const InputDecoration(labelText: '交易稅'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _taxTouched = true),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    !_taxTouched ? '自動：賣出 0.3%' : (isEdit ? '原本記錄的金額' : '已手動修改'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_side == TradeSide.buy ? '應付金額' : '應收金額'),
                Text(f0(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _accountId == null || code.isEmpty
                ? null
                : () async {
                    final shares = int.tryParse(_sharesCtrl.text);
                    final price = double.tryParse(_priceCtrl.text);
                    if (shares == null || shares <= 0 || price == null || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請填股數和成交價')),
                      );
                      return;
                    }
                    final name = repo.nameOf(code).isNotEmpty ? repo.nameOf(code) : code;
                    if (isEdit) {
                      await repo.updateTrade(
                        widget.tradeId!,
                        date: _date,
                        code: code,
                        name: name,
                        side: _side,
                        shares: shares,
                        price: price,
                        fee: fee,
                        tax: tax,
                      );
                    } else {
                      await repo.addTrade(
                        accountId: _accountId!,
                        date: _date,
                        code: code,
                        name: name,
                        side: _side,
                        shares: shares,
                        price: price,
                        fee: fee,
                        tax: tax,
                      );
                    }
                    if (context.mounted) {
                      final nav = Navigator.of(context);
                      if (nav.canPop()) {
                        nav.pop();
                      } else {
                        context.read<ShellController>().closeDetail();
                      }
                    }
                  },
            child: const Text('儲存'),
          ),
          if (isEdit) ...[
            const SizedBox(height: 10),
            if (!_confirmDelete)
              OutlinedButton(
                onPressed: () => setState(() => _confirmDelete = true),
                child: const Text('刪除這筆交易'),
              )
            else
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _confirmDelete = false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () async {
                      await repo.removeTrade(widget.tradeId!);
                      if (context.mounted) {
                        final nav = Navigator.of(context);
                        if (nav.canPop()) {
                          nav.pop();
                        } else {
                          context.read<ShellController>().closeDetail();
                        }
                      }
                    },
                    child: const Text('確定刪除'),
                  ),
                ),
              ]),
          ],
        ],
      ),
    );
  }
}
