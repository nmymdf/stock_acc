import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repository.dart';
import 'services/news_cache.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StockAccApp());
}

class StockAccApp extends StatelessWidget {
  const StockAccApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppRepository()..load()),
        ChangeNotifierProvider(create: (_) => NewsCache()),
      ],
      child: MaterialApp(
        title: '股票記帳',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    if (!repo.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const HomeShell();
  }
}
