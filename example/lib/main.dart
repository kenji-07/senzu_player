import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'features/feature_list.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SenzuDemoApp());
}

class SenzuDemoApp extends StatelessWidget {
  const SenzuDemoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SenzuPlayer Demo',
      debugShowCheckedModeBanner: false,
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00CA13),
          secondary: Color(0xFF00CA13),
        ),
      ),
      home: const FeatureListPage(),
    );
  }
}
