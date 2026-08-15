import 'package:flutter/material.dart';

/// Leaves a tool workspace by popping back to the existing Home route so its
/// scroll position survives; only rebuilds Home when there is nothing to pop.
void closeToolWorkspace(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  navigator.pushReplacementNamed('/home');
}
