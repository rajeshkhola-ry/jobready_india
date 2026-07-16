import 'file_picker_service.dart';

class UploadContextService {
  static List<PickedFileData> _uploadedFiles = const [];

  static void setLastPickedFile(PickedFileData file) {
    _uploadedFiles = [file];
  }

  static PickedFileData? getLastPickedFile() {
    if (_uploadedFiles.isEmpty) {
      return null;
    }
    return _uploadedFiles.first;
  }

  static PickedFileData? consumeLastPickedFile() {
    if (_uploadedFiles.isEmpty) {
      return null;
    }

    final file = _uploadedFiles.first;
    _uploadedFiles = _uploadedFiles.skip(1).toList(growable: false);
    return file;
  }

  static void setUploadedFiles(List<PickedFileData> files) {
    _uploadedFiles = List<PickedFileData>.from(files, growable: false);
  }

  static List<PickedFileData> getUploadedFiles() {
    return List<PickedFileData>.from(_uploadedFiles, growable: false);
  }

  static void clearUploadedFiles() {
    _uploadedFiles = const [];
  }

  static List<PickedFileData> getCompatibleFiles(List<String> allowedExtensions) {
    final normalized = allowedExtensions.map((item) => item.toLowerCase()).toSet();
    return _uploadedFiles.where((file) {
      final parts = file.name.toLowerCase().split('.');
      if (parts.length < 2) {
        return false;
      }
      return normalized.contains(parts.last);
    }).toList(growable: false);
  }

  static PickedFileData? getFirstCompatibleFile(List<String> allowedExtensions) {
    final matches = getCompatibleFiles(allowedExtensions);
    return matches.isEmpty ? null : matches.first;
  }
}
