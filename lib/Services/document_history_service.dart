import 'dart:convert';

import 'package:universal_html/html.dart' as html;

import 'user_account_service.dart';

class DocumentHistoryEntry {
  final String id;
  final String fileName;
  final String outputFormat;
  final int fileSizeBytes;
  final String recordedAtIso;

  const DocumentHistoryEntry({
    required this.id,
    required this.fileName,
    required this.outputFormat,
    required this.fileSizeBytes,
    required this.recordedAtIso,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_name': fileName,
      'output_format': outputFormat,
      'file_size_bytes': fileSizeBytes,
      'recorded_at_iso': recordedAtIso,
    };
  }

  factory DocumentHistoryEntry.fromMap(Map<String, dynamic> map) {
    return DocumentHistoryEntry(
      id: map['id']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? 'unknown',
      outputFormat: map['output_format']?.toString() ?? 'unknown',
      fileSizeBytes: int.tryParse(map['file_size_bytes']?.toString() ?? '0') ?? 0,
      recordedAtIso: map['recorded_at_iso']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  DateTime get recordedAt {
    return DateTime.tryParse(recordedAtIso) ?? DateTime.now();
  }
}

class DocumentHistoryService {
  static const String _storageKey = 'jobready_document_history_v2';
  static const int _maxEntries = 100;

  static List<DocumentHistoryEntry> getEntries() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.trim().isEmpty) {
      return const <DocumentHistoryEntry>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <DocumentHistoryEntry>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => DocumentHistoryEntry.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const <DocumentHistoryEntry>[];
    }
  }

  static Future<void> addEntry({
    required String fileName,
    required String outputFormat,
    required int fileSizeBytes,
  }) async {
    final profile = UserAccountService.getProfile();
    if (!profile.historyEnabled) {
      return;
    }

    final current = getEntries().toList(growable: true);
    final now = DateTime.now();

    current.insert(
      0,
      DocumentHistoryEntry(
        id: now.microsecondsSinceEpoch.toString(),
        fileName: fileName,
        outputFormat: outputFormat,
        fileSizeBytes: fileSizeBytes,
        recordedAtIso: now.toIso8601String(),
      ),
    );

    final trimmed = current.take(_maxEntries).map((entry) => entry.toMap()).toList(growable: false);
    html.window.localStorage[_storageKey] = jsonEncode(trimmed);
  }

  static Future<void> clear() async {
    html.window.localStorage.remove(_storageKey);
  }
}
