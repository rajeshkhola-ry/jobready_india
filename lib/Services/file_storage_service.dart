import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

/// Global file storage service for sharing uploaded files across tool pages
class StoredFile {
  final String id;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final String uploadedAtIso;
  final String base64Data; // Compressed storage in base64

  const StoredFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAtIso,
    required this.base64Data,
  });

  // Decompress base64 to bytes
  Uint8List getBytes() {
    return Uint8List.fromList(base64Decode(base64Data));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'uploaded_at_iso': uploadedAtIso,
      'base64_data': base64Data,
    };
  }

  factory StoredFile.fromMap(Map<String, dynamic> map) {
    return StoredFile(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'unknown',
      mimeType: map['mime_type']?.toString() ?? 'application/octet-stream',
      sizeBytes: int.tryParse(map['size_bytes']?.toString() ?? '0') ?? 0,
      uploadedAtIso: map['uploaded_at_iso']?.toString() ?? DateTime.now().toIso8601String(),
      base64Data: map['base64_data']?.toString() ?? '',
    );
  }

  factory StoredFile.fromBytes({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) {
    return StoredFile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      uploadedAtIso: DateTime.now().toIso8601String(),
      base64Data: base64Encode(bytes),
    );
  }

  DateTime get uploadedAt {
    return DateTime.tryParse(uploadedAtIso) ?? DateTime.now();
  }
}

class FileStorageService {
  static const String _storageKey = 'jobready_file_storage_v1';
  static const String _maxFilesKey = 'jobready_file_storage_count';
  static const int _maxStoredFiles = 5;

  /// Store a file for access across tool pages
  static Future<bool> storeFile({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final storedFile = StoredFile.fromBytes(
        name: name,
        bytes: bytes,
        mimeType: mimeType,
      );

      final current = getStoredFiles().toList(growable: true);
      current.insert(0, storedFile);

      // Keep only last N files to avoid localStorage limits
      final trimmed = current.take(_maxStoredFiles).map((f) => f.toMap()).toList();
      html.window.localStorage[_storageKey] = jsonEncode(trimmed);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all stored files
  static List<StoredFile> getStoredFiles() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null || raw.trim().isEmpty) {
        return const <StoredFile>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <StoredFile>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => StoredFile.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const <StoredFile>[];
    }
  }

  /// Get the most recently stored file
  static StoredFile? getLatestFile() {
    final files = getStoredFiles();
    return files.isNotEmpty ? files.first : null;
  }

  /// Get file by ID
  static StoredFile? getFileById(String id) {
    final files = getStoredFiles();
    try {
      return files.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Remove a stored file
  static Future<void> removeFile(String id) async {
    try {
      final current = getStoredFiles().toList(growable: true);
      current.removeWhere((f) => f.id == id);

      if (current.isEmpty) {
        html.window.localStorage.remove(_storageKey);
      } else {
        html.window.localStorage[_storageKey] = jsonEncode(current.map((f) => f.toMap()).toList());
      }
    } catch (_) {
      // Ignore storage removal failures.
    }
  }

  /// Clear all stored files
  static Future<void> clearAll() async {
    try {
      html.window.localStorage.remove(_storageKey);
    } catch (_) {
      // Ignore storage clear failures.
    }
  }

  /// Check if a file exists by name
  static bool hasFileWithName(String name) {
    final files = getStoredFiles();
    return files.any((f) => f.name == name);
  }
}
