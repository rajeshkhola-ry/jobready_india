import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

const int _maxFileSizeBytes = 500 * 1024 * 1024; // 500 MB — matches ApiConfig.maxFileSize

bool isFileSizeAcceptable(int sizeBytes) => sizeBytes <= _maxFileSizeBytes;

String formatFileSizeWarning(String fileName, int sizeBytes) {
  final mb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
  return '$fileName ($mb MB) exceeds the 500 MB file size limit and was skipped.';
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

  static Future<PlatformFile?> pickFile({List<String>? allowedExtensions}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      withReadStream: _enableReadStream,
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.first;
  }

  static Future<PickedFileData?> pickFileData({List<String>? allowedExtensions}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      withReadStream: _enableReadStream,
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final bytes = await _resolveBytes(file);
    if (bytes == null) {
      return null;
    }

    return PickedFileData(name: file.name, size: file.size, bytes: bytes);
  }

  static Future<List<PickedFileData>> pickMultipleFileData({
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      withReadStream: _enableReadStream,
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result == null || result.files.isEmpty) {
      return const [];
    }

    final picked = <PickedFileData>[];
    for (final file in result.files) {
      if (!isFileSizeAcceptable(file.size)) {
        continue; // silently skip oversized files; caller may check count delta
      }
      final bytes = await _resolveBytes(file);
      if (bytes != null) {
        picked.add(PickedFileData(name: file.name, size: file.size, bytes: bytes));
      }
    }

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

    final chunks = <int>[];
    await for (final chunk in stream) {
      chunks.addAll(chunk);
    }

    if (chunks.isEmpty) {
      return null;
    }

    return Uint8List.fromList(chunks);
  }
}
