import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:file_picker/file_picker.dart';

const int _maxFileSizeBytes = 500 * 1024 * 1024; // 500 MB — matches ApiConfig.maxFileSize

bool isFileSizeAcceptable(int sizeBytes) => sizeBytes <= _maxFileSizeBytes;

String formatFileSizeWarning(String fileName, int sizeBytes) {
  final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
  return '$fileName ($mb MB) exceeds the 500 MB file size limit and was skipped.';
}

class FileSelectionReport {
  final bool cancelled;
  final int requestedFileCount;
  final int acceptedFileCount;
  final int skippedOversizedCount;
  final int skippedDuplicateCount;
  final int skippedUnreadableCount;

  const FileSelectionReport({
    required this.cancelled,
    required this.requestedFileCount,
    required this.acceptedFileCount,
    required this.skippedOversizedCount,
    required this.skippedDuplicateCount,
    required this.skippedUnreadableCount,
  });

  static const empty = FileSelectionReport(
    cancelled: false,
    requestedFileCount: 0,
    acceptedFileCount: 0,
    skippedOversizedCount: 0,
    skippedDuplicateCount: 0,
    skippedUnreadableCount: 0,
  );

  bool get hasFilteredFiles =>
      skippedOversizedCount > 0 ||
      skippedDuplicateCount > 0 ||
      skippedUnreadableCount > 0;

  String buildSummaryMessage() {
    final parts = <String>[];
    if (skippedOversizedCount > 0) {
      parts.add('$skippedOversizedCount oversized');
    }
    if (skippedDuplicateCount > 0) {
      parts.add('$skippedDuplicateCount duplicate');
    }
    if (skippedUnreadableCount > 0) {
      parts.add('$skippedUnreadableCount unreadable');
    }
    if (parts.isEmpty) {
      return '';
    }
    return 'Some files were skipped: ${parts.join(', ')}. Please review your files and try again.';
  }
}

class PickedFileData {
  final String name;
  final int size;
  final Uint8List bytes;

  const PickedFileData({
    required this.name,
    required this.size,
    required this.bytes,
  });
}

class FilePickerService {
  static bool get _enableReadStream => !kIsWeb;
  static FileSelectionReport _lastSelectionReport = FileSelectionReport.empty;

  static FileSelectionReport get lastSelectionReport => _lastSelectionReport;

  static Future<PlatformFile?> pickFile({List<String>? allowedExtensions}) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        withReadStream: _enableReadStream,
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
      );
    } on PlatformException {
      result = null;
    }

    if (result == null || result.files.isEmpty) {
      _lastSelectionReport = const FileSelectionReport(
        cancelled: true,
        requestedFileCount: 0,
        acceptedFileCount: 0,
        skippedOversizedCount: 0,
        skippedDuplicateCount: 0,
        skippedUnreadableCount: 0,
      );
      return null;
    }

    _lastSelectionReport = const FileSelectionReport(
      cancelled: false,
      requestedFileCount: 1,
      acceptedFileCount: 1,
      skippedOversizedCount: 0,
      skippedDuplicateCount: 0,
      skippedUnreadableCount: 0,
    );

    return result.files.first;
  }

  static Future<PickedFileData?> pickFileData({List<String>? allowedExtensions}) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        withReadStream: _enableReadStream,
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
      );
    } on PlatformException {
      result = null;
    }

    if (result == null || result.files.isEmpty) {
      _lastSelectionReport = const FileSelectionReport(
        cancelled: true,
        requestedFileCount: 0,
        acceptedFileCount: 0,
        skippedOversizedCount: 0,
        skippedDuplicateCount: 0,
        skippedUnreadableCount: 0,
      );
      return null;
    }

    final file = result.files.first;
    if (!isFileSizeAcceptable(file.size)) {
      _lastSelectionReport = const FileSelectionReport(
        cancelled: false,
        requestedFileCount: 1,
        acceptedFileCount: 0,
        skippedOversizedCount: 1,
        skippedDuplicateCount: 0,
        skippedUnreadableCount: 0,
      );
      return null;
    }

    final bytes = await _resolveBytes(file);
    if (bytes == null) {
      _lastSelectionReport = const FileSelectionReport(
        cancelled: false,
        requestedFileCount: 1,
        acceptedFileCount: 0,
        skippedOversizedCount: 0,
        skippedDuplicateCount: 0,
        skippedUnreadableCount: 1,
      );
      return null;
    }

    _lastSelectionReport = const FileSelectionReport(
      cancelled: false,
      requestedFileCount: 1,
      acceptedFileCount: 1,
      skippedOversizedCount: 0,
      skippedDuplicateCount: 0,
      skippedUnreadableCount: 0,
    );

    return PickedFileData(name: file.name, size: file.size, bytes: bytes);
  }

  static Future<List<PickedFileData>> pickMultipleFileData({
    List<String>? allowedExtensions,
  }) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        withReadStream: _enableReadStream,
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
      );
    } on PlatformException {
      result = null;
    }

    if (result == null || result.files.isEmpty) {
      _lastSelectionReport = const FileSelectionReport(
        cancelled: true,
        requestedFileCount: 0,
        acceptedFileCount: 0,
        skippedOversizedCount: 0,
        skippedDuplicateCount: 0,
        skippedUnreadableCount: 0,
      );
      return const [];
    }

    final picked = <PickedFileData>[];
    final seenSignatures = <String>{};
    var skippedOversizedCount = 0;
    var skippedDuplicateCount = 0;
    var skippedUnreadableCount = 0;

    for (final file in result.files) {
      if (!isFileSizeAcceptable(file.size)) {
        skippedOversizedCount++;
        continue;
      }

      final signature = '${file.name.toLowerCase()}|${file.size}';
      if (seenSignatures.contains(signature)) {
        skippedDuplicateCount++;
        continue;
      }

      final bytes = await _resolveBytes(file);
      if (bytes != null) {
        seenSignatures.add(signature);
        picked.add(PickedFileData(name: file.name, size: file.size, bytes: bytes));
      } else {
        skippedUnreadableCount++;
      }
    }

    _lastSelectionReport = FileSelectionReport(
      cancelled: false,
      requestedFileCount: result.files.length,
      acceptedFileCount: picked.length,
      skippedOversizedCount: skippedOversizedCount,
      skippedDuplicateCount: skippedDuplicateCount,
      skippedUnreadableCount: skippedUnreadableCount,
    );

    return picked;
  }

  static Future<Uint8List?> _resolveBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes;
    }

    final stream = file.readStream;
    if (stream == null) {
      return null;
    }

    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }

      if (builder.isEmpty) {
        return null;
      }

      return builder.takeBytes();
    } catch (_) {
      // Large/corrupt streams can throw mid-read (e.g. browser memory pressure) -
      // treat as unreadable instead of propagating a crash.
      return null;
    }
  }
}
