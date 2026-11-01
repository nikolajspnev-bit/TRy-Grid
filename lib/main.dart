import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor.dart';
import 'store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(TRyGridApp(store: CollageStore()));
}

class TRyGridApp extends StatelessWidget {
  const TRyGridApp({super.key, required this.store});
  final CollageStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TRy Grid',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: EditorScreen(store: store),
    );
  }
}
