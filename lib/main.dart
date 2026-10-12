import 'package:flutter/material.dart';

import 'home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutoAnswerApp());
}

class AutoAnswerApp extends StatelessWidget {
  const AutoAnswerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '自动接电话',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B873F)),
      ),
      home: const HomePage(),
    );
  }
}