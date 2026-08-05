import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum PosterLayerType { text, shape, image, icon, badge }

enum PosterShapeType { rectangle, circle, pill }

class PosterStudioTemplate {
  final String id;
  final String title;
  final String category;
  final String description;
  final List<Color> gradientColors;
  final List<PosterLayerDraft> layers;

  const PosterStudioTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.gradientColors,
    required this.layers,
  });
}

class PosterLayerDraft {
  final PosterLayerType type;
  final String label;
  final Offset position;
  final Size size;
  final double rotation;
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color fillColor;
  final Color textColor;
  final IconData? iconData;
  final PosterShapeType shapeType;
  final double borderRadius;

  const PosterLayerDraft({
    required this.type,
    required this.label,
    required this.position,
    required this.size,
    this.rotation = 0,
    this.text = '',
    this.fontSize = 18,
    this.fontWeight = FontWeight.w700,
    this.fillColor = const Color(0xFFFFFFFF),
    this.textColor = const Color(0xFF0F172A),
    this.iconData,
    this.shapeType = PosterShapeType.rectangle,
    this.borderRadius = 18,
  });
}

class PosterBannerStudioService {
  const PosterBannerStudioService._();

  static const List<PosterStudioTemplate> templates = <PosterStudioTemplate>[
    PosterStudioTemplate(
      id: 'hiring_drive_blue',
      title: 'Hiring Drive Spotlight',
      category: 'Hiring',
      description: 'Recruitment poster for walk-ins, openings, and campus drives.',
      gradientColors: <Color>[Color(0xFF0F2E56), Color(0xFF1E5B88), Color(0xFF56B8D9)],
      layers: <PosterLayerDraft>[
        PosterLayerDraft(
          type: PosterLayerType.badge,
          label: 'Badge',
          position: Offset(24, 24),
          size: Size(150, 40),
          text: 'NOW HIRING',
          fontSize: 16,
          fillColor: Color(0xFFFFC857),
          textColor: Color(0xFF172033),
          borderRadius: 999,
        ),
        PosterLayerDraft(
          type: PosterLayerType.text,
          label: 'Headline',
          position: Offset(26, 92),
          size: Size(280, 100),
          text: 'Join Our Career Acceleration Team',
          fontSize: 28,
          fillColor: Colors.transparent,
          textColor: Colors.white,
        ),
        PosterLayerDraft(
          type: PosterLayerType.text,
          label: 'Body',
          position: Offset(28, 206),
          size: Size(250, 92),
          text: 'Walk-in interviews • Flexible shifts • Training included',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fillColor: Colors.transparent,
          textColor: Color(0xFFE2F3FF),
        ),
        PosterLayerDraft(
          type: PosterLayerType.icon,
          label: 'Career Icon',
          position: Offset(246, 106),
          size: Size(92, 92),
          iconData: Icons.work_outline_rounded,
          fillColor: Color(0xFFFFC857),
        ),
      ],
    ),
    PosterStudioTemplate(
      id: 'business_sale_sunrise',
      title: 'Business Promo Burst',
      category: 'Business Promotions',
      description: 'Discount banner for retail, salon, coaching, and local stores.',
      gradientColors: <Color>[Color(0xFF7A1F1F), Color(0xFFD94841), Color(0xFFFFD166)],
      layers: <PosterLayerDraft>[
        PosterLayerDraft(
          type: PosterLayerType.text,
          label: 'Headline',
          position: Offset(24, 44),
          size: Size(260, 90),
          text: 'Mega Weekend Offer',
          fontSize: 30,
          fillColor: Colors.transparent,
          textColor: Colors.white,
        ),
        PosterLayerDraft(
          type: PosterLayerType.badge,
          label: 'Discount',
          position: Offset(26, 154),
          size: Size(124, 124),
          text: '50%\nOFF',
          fontSize: 24,
          fillColor: Color(0xFFFFF4D6),
          textColor: Color(0xFF7A1F1F),
          shapeType: PosterShapeType.circle,
          borderRadius: 999,
        ),
        PosterLayerDraft(
          type: PosterLayerType.text,
          label: 'Footer',
          position: Offset(176, 198),
          size: Size(140, 82),
          text: 'Visit today\nCall now',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fillColor: Colors.transparent,
          textColor: Color(0xFFFFF7E8),
        ),
      ],
    ),
    PosterStudioTemplate(
      id: 'festival_gold_green',
      title: 'Festival Greetings Banner',
      category: 'Festivals',
      description: 'Celebration banner with greeting headline and sponsor space.',
      gradientColors: <Color>[Color(0xFF0B3D2E), Color(0xFF14746F), Color(0xFFFFD166)],
      layers: <PosterLayerDraft>[
        PosterLayerDraft(
          type: PosterLayerType.shape,
          label: 'Glow Panel',
          position: Offset(24, 58),
          size: Size(292, 196),
          fillColor: Color(0x33FFF9E6),
          shapeType: PosterShapeType.pill,
          borderRadius: 28,
        ),
        PosterLayerDraft(
          type: PosterLayerType.text,
          label: 'Greeting',
          position: Offset(42, 86),
          size: Size(242, 88),
          text: 'Happy Festival\nTo You & Family',
          fontSize: 26,
          textColor: Colors.white,
          fillColor: Colors.transparent,
        ),
        PosterLayerDraft(
          type: PosterLayerType.badge,
          label: 'Sponsor',
          position: Offset(44, 204),
          size: Size(180, 40),
          text: 'Presented by GETREADYJOB',
          fontSize: 14,
          fillColor: Color(0xFFFFD166),
          textColor: Color(0xFF123A63),
          borderRadius: 999,
        ),
      ],
    ),
    PosterStudioTemplate(
      id: 'govt_notice_civic',
      title: 'Govt Notice Board',
      category: 'Govt Announcements',
      description: 'Public notice or official update banner with restrained visual hierarchy.',
      gradientColors: <Color>[Color(0xFFE7EEF5), Color(0xFFD8E6F2), Color(0xFFF8FBFF)],
      layers: <PosterLayerDraft>[
        PosterLayerDraft(
          type: PosterLayerType.badge,
          label: 'Header Badge',
          position: Offset(26, 28),
          size: Size(170, 36),
          text: 'PUBLIC ANNOUNCEMENT',
          fontSize: 14,
          fillColor: Color(0xFF123A63),
          textColor: Colors.white,
          borderRadius: 8,
        ),
        PosterLayerDraft(
          type: PosterLayerType.text,
          label: 'Headline',
          position: Offset(24, 84),
          size: Size(286, 96),
          text: 'Important Update Regarding Application Window',
          fontSize: 27,
          textColor: Color(0xFF0F172A),
          fillColor: Colors.transparent,
        ),
        PosterLayerDraft(
          type: PosterLayerType.text,
          label: 'Body',
          position: Offset(26, 188),
          size: Size(280, 96),
          text: 'Submit documents before 30 August. Contact the local help desk for assistance.',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          textColor: Color(0xFF334155),
          fillColor: Colors.transparent,
        ),
      ],
    ),
  ];

  static List<String> get categories => templates.map((template) => template.category).toSet().toList();

  static PdfColor toPdfColor(Color color) {
    return PdfColor(color.r / 255, color.g / 255, color.b / 255, color.a / 255);
  }

  static Future<Uint8List> buildPosterPdf({
    required Size canvasSize,
    required List<Color> gradientColors,
    required List<PosterLayerDraft> layers,
    Uint8List? uploadedImageBytes,
  }) async {
    final doc = pw.Document();
    final pageFormat = PdfPageFormat(canvasSize.width * 1.8, canvasSize.height * 1.8);
    final imageProvider = uploadedImageBytes != null && uploadedImageBytes.isNotEmpty ? pw.MemoryImage(uploadedImageBytes) : null;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Container(
            width: pageFormat.width,
            height: pageFormat.height,
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
                colors: gradientColors.map(toPdfColor).toList(),
              ),
            ),
            child: pw.Stack(
              children: layers.map((layer) {
                final left = (layer.position.dx / canvasSize.width) * pageFormat.width;
                final top = (layer.position.dy / canvasSize.height) * pageFormat.height;
                final width = (layer.size.width / canvasSize.width) * pageFormat.width;
                final height = (layer.size.height / canvasSize.height) * pageFormat.height;

                return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.Transform.rotate(
                    angle: layer.rotation,
                    child: _buildPdfLayer(layer, width, height, imageProvider),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildPdfLayer(
    PosterLayerDraft layer,
    double width,
    double height,
    pw.MemoryImage? imageProvider,
  ) {
    switch (layer.type) {
      case PosterLayerType.text:
        return pw.SizedBox(
          width: width,
          height: height,
          child: pw.Text(
            layer.text,
            style: pw.TextStyle(
              color: toPdfColor(layer.textColor),
              fontSize: layer.fontSize * 1.75,
              fontWeight: _pdfFontWeight(layer.fontWeight),
            ),
          ),
        );
      case PosterLayerType.shape:
      case PosterLayerType.badge:
        return pw.Container(
          width: width,
          height: height,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: toPdfColor(layer.fillColor),
            borderRadius: pw.BorderRadius.circular(layer.borderRadius),
          ),
          child: layer.text.trim().isEmpty
              ? null
              : pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(
                    layer.text,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: toPdfColor(layer.textColor),
                      fontSize: layer.fontSize * 1.55,
                      fontWeight: _pdfFontWeight(layer.fontWeight),
                    ),
                  ),
                ),
        );
      case PosterLayerType.icon:
        return pw.Container(
          width: width,
          height: height,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: toPdfColor(layer.fillColor),
            borderRadius: pw.BorderRadius.circular(layer.borderRadius),
          ),
          child: pw.Text(
            layer.text.isEmpty ? 'ICON' : layer.text,
            style: pw.TextStyle(
              color: toPdfColor(layer.textColor),
              fontSize: layer.fontSize * 1.5,
              fontWeight: _pdfFontWeight(layer.fontWeight),
            ),
          ),
        );
      case PosterLayerType.image:
        return pw.Container(
          width: width,
          height: height,
          decoration: pw.BoxDecoration(
            color: toPdfColor(layer.fillColor),
            borderRadius: pw.BorderRadius.circular(layer.borderRadius),
          ),
          child: imageProvider == null
              ? pw.Center(
                  child: pw.Text(
                    'IMAGE',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: layer.fontSize * 1.25,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                )
              : pw.ClipRRect(
                  horizontalRadius: layer.borderRadius,
                  verticalRadius: layer.borderRadius,
                  child: pw.Image(imageProvider, width: width, height: height, fit: pw.BoxFit.cover),
                ),
        );
    }
  }

  static pw.FontWeight _pdfFontWeight(FontWeight weight) {
    if (weight == FontWeight.w900 ||
        weight == FontWeight.w800 ||
        weight == FontWeight.w700 ||
        weight == FontWeight.w600) {
      return pw.FontWeight.bold;
    }
    return pw.FontWeight.normal;
  }
}
