import 'dart:typed_data';

import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'file_picker_service.dart';

class PdfMergeService {
	const PdfMergeService();

	Future<Uint8List> mergePdfs(List<PickedFileData> files) async {
		if (files.length < 2) {
			throw Exception('Select at least 2 PDF files to merge');
		}

		final outputPdf = PdfDocument();

		try {
			for (final file in files) {
				if (file.bytes.isEmpty) {
					throw Exception('File ${file.name} has no data');
				}

				final inputPdf = PdfDocument(inputBytes: file.bytes);
				try {
					for (var i = 0; i < inputPdf.pages.count; i++) {
						final sourcePage = inputPdf.pages[i];
						final template = sourcePage.createTemplate();
						final mergedPage = outputPdf.pages.add();
						mergedPage.graphics.drawPdfTemplate(
							template,
							Offset.zero,
							sourcePage.size,
						);
					}
				} finally {
					inputPdf.dispose();
				}
			}

			return Uint8List.fromList(outputPdf.saveSync());
		} finally {
			outputPdf.dispose();
		}
	}
}
