import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

class GeneratedFile {
	final String name;
	final Uint8List bytes;

	const GeneratedFile({required this.name, required this.bytes});
}

class PdfEditorService {
	const PdfEditorService();

	Future<List<GeneratedFile>> splitPdfByRanges(
		Uint8List pdfBytes,
		String fileName,
		List<String> ranges,
	) async {
		final source = sfpdf.PdfDocument(inputBytes: pdfBytes);
		try {
			final files = <GeneratedFile>[];
			for (final range in ranges) {
				final pages = _parseRange(range, source.pages.count);
				if (pages.isEmpty) {
					continue;
				}

				final output = await _buildPdfFromSyncfusionPages(source, pages);
				files.add(
					GeneratedFile(
						name: '${_baseName(fileName)}_pages_${range.replaceAll(RegExp(r'[^0-9-]'), '_')}.pdf',
						bytes: output,
					),
				);
			}
			return files;
		} finally {
			source.dispose();
		}
	}

	Future<Uint8List> _buildPdfFromSyncfusionPages(sfpdf.PdfDocument source, List<int> pages) async {
		final outputPdf = sfpdf.PdfDocument();
		try {
			for (final pageNumber in pages) {
				final sourcePage = source.pages[pageNumber - 1];
				final template = sourcePage.createTemplate();
				final outputPage = outputPdf.pages.add();
				outputPage.graphics.drawPdfTemplate(
					template,
					Offset.zero,
					sourcePage.size,
				);
			}

			return Uint8List.fromList(outputPdf.saveSync());
		} finally {
			outputPdf.dispose();
		}
	}

	Future<List<GeneratedFile>> extractPageImages(
		Uint8List pdfBytes,
		String fileName,
		List<int> pages,
	) async {
		final source = sfpdf.PdfDocument(inputBytes: pdfBytes);
		try {
			final files = <GeneratedFile>[];
			for (final pageNumber in pages) {
				if (pageNumber < 1 || pageNumber > source.pages.count) {
					continue;
				}

				final pngBytes = _buildWebFallbackPageImage(pageNumber, source.pages.count);
				files.add(
					GeneratedFile(
						name: '${_baseName(fileName)}_page_$pageNumber.png',
						bytes: pngBytes,
					),
				);
			}
			return files;
		} finally {
			source.dispose();
		}
	}

	Uint8List _buildWebFallbackPageImage(int pageNumber, int totalPages) {
		final canvas = img.Image(width: 1200, height: 1600);
		img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
		img.drawRect(canvas, x1: 24, y1: 24, x2: 1176, y2: 1576, color: img.ColorRgb8(40, 60, 100), thickness: 6);
		img.drawString(
			canvas,
			'JOBREADY Extract Preview',
			font: img.arial48,
			x: 90,
			y: 120,
			color: img.ColorRgb8(31, 41, 55),
		);
		img.drawString(
			canvas,
			'Page $pageNumber of $totalPages',
			font: img.arial24,
			x: 90,
			y: 240,
			color: img.ColorRgb8(59, 130, 246),
		);
		img.drawString(
			canvas,
			'Web compatibility mode output',
			font: img.arial24,
			x: 90,
			y: 320,
			color: img.ColorRgb8(120, 120, 120),
		);
		return Uint8List.fromList(img.encodePng(canvas));
	}

	List<int> _parseRange(String range, int maxPage) {
		final trimmed = range.trim();
		if (trimmed.isEmpty) {
			return const [];
		}

		if (trimmed.contains('-')) {
			final parts = trimmed.split('-');
			if (parts.length != 2) {
				return const [];
			}
			final start = int.tryParse(parts[0].trim());
			final end = int.tryParse(parts[1].trim());
			if (start == null || end == null) {
				return const [];
			}
			final normalizedStart = min(start, end);
			final normalizedEnd = max(start, end);
			return [
				for (var page = normalizedStart; page <= normalizedEnd; page++)
					if (page >= 1 && page <= maxPage) page,
			];
		}

		final page = int.tryParse(trimmed);
		if (page == null || page < 1 || page > maxPage) {
			return const [];
		}
		return [page];
	}

	String _baseName(String fileName) {
		final dotIndex = fileName.lastIndexOf('.');
		return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
	}
}
