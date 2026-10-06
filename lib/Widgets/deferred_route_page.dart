import 'package:flutter/material.dart';

/// Hosts a `deferred as` tool page (compress, convert, photo-hd, etc.).
///
/// Bug fixed here: on a direct/deep link (or a fresh boot), calling
/// `widget.loader()` synchronously in `initState()` could race the app's
/// own boot sequence (CanvasKit/main.dart.js still finishing
/// initialization), and dart2js's deferred-library loader would fail after
/// its own internal retries. Because that failure was never caught, the
/// Future's error went unhandled, `_loaded` was never set, and the user was
/// left staring at an infinite "Loading..." spinner with no way out.
///
/// Fix: wait a frame (and a short beat) before the first attempt so boot has
/// a chance to finish, retry a couple of times with backoff if loading
/// fails, and if it still fails, show a real error state with a Retry
/// button instead of spinning forever.
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
  static const int _maxAttempts = 3;

  bool _loaded = false;
  bool _failed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _attempt += 1;
    final int thisAttempt = _attempt;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!mounted || thisAttempt != _attempt) return;

        widget.loader().then((_) {
          if (!mounted || thisAttempt != _attempt) return;
          setState(() {
            _loaded = true;
            _failed = false;
          });
        }).catchError((Object error, StackTrace stack) {
          debugPrint(
            'DeferredRoutePage: load attempt $thisAttempt failed: $error',
          );
          if (!mounted || thisAttempt != _attempt) return;

          if (thisAttempt < _maxAttempts) {
            Future<void>.delayed(
              Duration(milliseconds: 400 * thisAttempt),
              _load,
            );
          } else {
            setState(() {
              _failed = true;
            });
          }
        });
      });
    });
  }

  void _retry() {
    setState(() {
      _failed = false;
      _attempt = 0;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) {
      return widget.builder();
    }

    if (_failed) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFB91C1C),
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text(
                  'This tool could not be loaded.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _retry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
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
