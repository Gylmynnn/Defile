import 'package:defile/src/features/file_explorer/bindings/file_explorer_binding.dart';
import 'package:defile/src/features/file_explorer/views/file_explorer_page.dart';
import 'package:flutter/material.dart';
import 'package:defile/src/rust/frb_generated.dart';
import 'package:get/get.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      initialBinding: FileExplorerBinding(),
      home: const FileExplorerPage(),
    );
  }
}
