import 'package:flutter/material.dart';

class MinimalBootstrapApp extends StatelessWidget {
  const MinimalBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GETREADYJOB V1.1',
      home: Scaffold(
        body: Center(
          child: Text('GETREADYJOB V1.1'),
        ),
      ),
    );
  }
}
