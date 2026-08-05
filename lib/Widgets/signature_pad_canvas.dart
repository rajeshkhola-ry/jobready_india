import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';

class SignaturePadController {
  final List<List<Offset>> _strokes = <List<Offset>>[];

  List<List<Offset>> get strokes => _strokes;

  bool get hasSignature => _strokes.any((stroke) => stroke.length > 1);

  void clear() {
    _strokes.clear();
  }

  void startStroke(Offset point) {
    _strokes.add(<Offset>[point]);
  }

  void appendPoint(Offset point) {
    if (_strokes.isEmpty) {
      _strokes.add(<Offset>[point]);
      return;
    }
    _strokes.last.add(point);
  }

  Future<Uint8List> exportPng({
    required double width,
    required double height,
    Color strokeColor = const Color(0xFF0F172A),
    double strokeWidth = 2.8,
    bool transparentBackground = true,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    if (!transparentBackground) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.white,
      );
    }

    for (final stroke in _strokes) {
      if (stroke.isEmpty) {
        continue;
      }
      if (stroke.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round().clamp(1, 3000), height.round().clamp(1, 2000));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Unable to export signature image.');
    }
    return data.buffer.asUint8List();
  }
}

class SignaturePadCanvas extends StatefulWidget {
  const SignaturePadCanvas({
    super.key,
    required this.controller,
    this.height = 220,
    this.borderColor = const Color(0xFFC8D5E6),
    this.backgroundColor = Colors.white,
    this.strokeColor = const Color(0xFF0F172A),
  });

  final SignaturePadController controller;
  final double height;
  final Color borderColor;
  final Color backgroundColor;
  final Color strokeColor;

  @override
  State<SignaturePadCanvas> createState() => _SignaturePadCanvasState();
}

class _SignaturePadCanvasState extends State<SignaturePadCanvas> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.borderColor),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          setState(() {
            widget.controller.startStroke(details.localPosition);
          });
        },
        onPanUpdate: (details) {
          setState(() {
            widget.controller.appendPoint(details.localPosition);
          });
        },
        child: CustomPaint(
          painter: _SignaturePainter(
            strokes: widget.controller.strokes,
            color: widget.strokeColor,
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({
    required this.strokes,
    required this.color,
  });

  final List<List<Offset>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.8;

    for (final stroke in strokes) {
      if (stroke.isEmpty) {
        continue;
      }
      if (stroke.length == 1) {
        canvas.drawPoints(ui.PointMode.points, stroke, paint);
        continue;
      }

      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.color != color;
  }
}
