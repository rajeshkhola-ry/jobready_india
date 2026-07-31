import 'package:flutter/material.dart';

class DeferredRoutePage extends StatefulWidget {
  const DeferredRoutePage({
    super.key,
    required this.loader,
    required this.builder,
    this.loadingText = 'Loading...',
  });

  final Future<void> Function() loader;
  final Widget Function() builder;
  final String loadingText;

  @override
  State<DeferredRoutePage> createState() => _DeferredRoutePageState();
}

class _DeferredRoutePageState extends State<DeferredRoutePage> {
  late Future<void> _future;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _future = widget.loader().then((_) {
      if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) {
      return widget.builder();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(widget.loadingText),
          ],
        ),
      ),
    );
  }
}
