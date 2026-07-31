class PdfExportFormatter {
  const PdfExportFormatter();

  static List<String> prepareParagraphs(String editedText) {
    final normalized = editedText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalized.isEmpty) {
      return const [];
    }

    final paragraphs = <String>[];
    for (final block in normalized.split('\n\n')) {
      final paragraph = block
          .split('\n')
          .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((line) => line.isNotEmpty)
          .join(' ');

      if (paragraph.isNotEmpty) {
        paragraphs.add(paragraph);
      }
    }

    return paragraphs;
  }

  static List<String> wrapParagraph(String paragraph, {required int maxCharsPerLine}) {
    final words = paragraph.split(' ').where((word) => word.isNotEmpty).toList(growable: false);
    if (words.isEmpty) {
      return const [];
    }

    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (word.length > maxCharsPerLine) {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
          currentLine = '';
        }
        lines.add(word);
        continue;
      }

      final candidate = currentLine.isEmpty ? word : '$currentLine $word';
      if (candidate.length <= maxCharsPerLine) {
        currentLine = candidate;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }
}
