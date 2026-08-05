import 'dart:convert';

import 'package:flutter/material.dart';

import '../Services/poster_banner_studio_service.dart';
import '../Utils/web_safe_browser.dart';

// localStorage keys
const String _kPosterKey = 'grj_poster_draft_v1';
const String _kQrKey = 'grj_qr_draft_v1';
const String _kMasksKey = 'grj_masks_draft_v1';

/// Lightweight auto-save/restore for Poster Studio and Privacy Masker state.
/// All data is stored in browser localStorage as JSON — no server, no images.
class DraftPersistenceService {
  const DraftPersistenceService._();

  // ── Poster Studio ──────────────────────────────────────────────────────────

  static void savePosterDraft({
    required String templateId,
    required List<PosterLayerDraft> layers,
    required String fontFamily,
    required String fontScript,
    required int selectedLayerIndex,
  }) {
    final map = <String, dynamic>{
      'savedAt': DateTime.now().toIso8601String(),
      'templateId': templateId,
      'fontFamily': fontFamily,
      'fontScript': fontScript,
      'selectedLayerIndex': selectedLayerIndex,
      'layers': layers.map(_layerToMap).toList(),
    };
    WebSafeBrowser.writeLocalStorage(_kPosterKey, jsonEncode(map));
  }

  static Map<String, dynamic>? loadPosterDraft() {
    final raw = WebSafeBrowser.readLocalStorage(_kPosterKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Returns deserialized layers from a loaded draft map, or null on failure.
  static List<PosterLayerDraft>? parseLayers(Map<String, dynamic> draft) {
    try {
      final rawLayers = draft['layers'] as List<dynamic>;
      return rawLayers.map((e) => _layerFromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  static void clearPosterDraft() => WebSafeBrowser.removeLocalStorage(_kPosterKey);

  // ── QR Generator ──────────────────────────────────────────────────────────

  static void saveQrDraft({
    required String text,
    required String scheme,
    required double size,
    required String colorScheme,
  }) {
    final map = <String, dynamic>{
      'savedAt': DateTime.now().toIso8601String(),
      'text': text,
      'scheme': scheme,
      'size': size,
      'colorScheme': colorScheme,
    };
    WebSafeBrowser.writeLocalStorage(_kQrKey, jsonEncode(map));
  }

  static Map<String, dynamic>? loadQrDraft() {
    final raw = WebSafeBrowser.readLocalStorage(_kQrKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void clearQrDraft() => WebSafeBrowser.removeLocalStorage(_kQrKey);

  // ── Privacy Masker — mask rects ────────────────────────────────────────────

  static void saveMaskDraft({required List<Rect> rects}) {
    final encoded = jsonEncode(<String, dynamic>{
      'savedAt': DateTime.now().toIso8601String(),
      'rects': rects.map((r) => [r.left, r.top, r.right, r.bottom]).toList(),
    });
    WebSafeBrowser.writeLocalStorage(_kMasksKey, encoded);
  }

  static ({List<Rect> rects, DateTime savedAt})? loadMaskDraft() {
    final raw = WebSafeBrowser.readLocalStorage(_kMasksKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final rawRects = map['rects'] as List<dynamic>;
      final rects = rawRects.map((e) {
        final coords = e as List<dynamic>;
        return Rect.fromLTRB(
          (coords[0] as num).toDouble(),
          (coords[1] as num).toDouble(),
          (coords[2] as num).toDouble(),
          (coords[3] as num).toDouble(),
        );
      }).toList();
      final savedAt = DateTime.tryParse(map['savedAt'] as String? ?? '') ?? DateTime.now();
      return (rects: rects, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  static void clearMaskDraft() => WebSafeBrowser.removeLocalStorage(_kMasksKey);

  // ── Time formatting ────────────────────────────────────────────────────────

  static String relativeTime(DateTime savedAt) {
    final diff = DateTime.now().difference(savedAt);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Layer serialization ────────────────────────────────────────────────────

  static Map<String, dynamic> _layerToMap(PosterLayerDraft l) => <String, dynamic>{
        'type': l.type.name,
        'label': l.label,
        'px': l.position.dx,
        'py': l.position.dy,
        'sw': l.size.width,
        'sh': l.size.height,
        'rot': l.rotation,
        'text': l.text,
        'fontSize': l.fontSize,
        'fwi': l.fontWeight.index,
        'fill': l.fillColor.value,
        'tc': l.textColor.value,
        'ico': l.iconData == null
            ? null
            : {
                'cp': l.iconData!.codePoint,
                'ff': l.iconData!.fontFamily,
                'fp': l.iconData!.fontPackage,
              },
        'shape': l.shapeType.name,
        'br': l.borderRadius,
      };

  static PosterLayerDraft _layerFromMap(Map<String, dynamic> m) {
    IconData? iconData;
    final icoMap = m['ico'] as Map<String, dynamic>?;
    if (icoMap != null) {
      iconData = IconData(
        icoMap['cp'] as int,
        fontFamily: icoMap['ff'] as String?,
        fontPackage: icoMap['fp'] as String?,
      );
    }

    return PosterLayerDraft(
      type: PosterLayerType.values.byName(m['type'] as String),
      label: m['label'] as String,
      position: Offset((m['px'] as num).toDouble(), (m['py'] as num).toDouble()),
      size: Size((m['sw'] as num).toDouble(), (m['sh'] as num).toDouble()),
      rotation: (m['rot'] as num? ?? 0).toDouble(),
      text: m['text'] as String? ?? '',
      fontSize: (m['fontSize'] as num? ?? 18).toDouble(),
      fontWeight: FontWeight.values[(m['fwi'] as int? ?? 4).clamp(0, 8)],
      fillColor: Color(m['fill'] as int? ?? 0xFFFFFFFF),
      textColor: Color(m['tc'] as int? ?? 0xFF0F172A),
      iconData: iconData,
      shapeType: PosterShapeType.values.byName(m['shape'] as String? ?? 'rectangle'),
      borderRadius: (m['br'] as num? ?? 18).toDouble(),
    );
  }
}
