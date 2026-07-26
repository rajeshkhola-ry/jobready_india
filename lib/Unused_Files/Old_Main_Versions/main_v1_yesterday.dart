import 'package:flutter/material.dart';

import 'main.dart' as legacy;

void main() {
  runApp(const JobReadyYesterdayV1App());
}

class JobReadyYesterdayV1App extends StatelessWidget {
  const JobReadyYesterdayV1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOBREADY V1',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      home: const legacy.HomePage(),
    );
  }
}
