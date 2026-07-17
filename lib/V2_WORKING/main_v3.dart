import 'package:flutter/material.dart';

import '../main_v3.dart' show JobReadyV3App;

void main() {
  // Working-lane entrypoint that keeps V2 execution isolated from V1 flow.
  runApp(const JobReadyV3App());
}
