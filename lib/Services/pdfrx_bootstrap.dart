import 'package:pdfrx/pdfrx.dart';

bool _initialized = false;

/// Initialises pdfrx (PDFium) once per session.
///
/// pdfrx 2.x refuses to open a document until its entry functions are
/// registered, and throws "PdfrxEntryFunctions.instance is not initialized"
/// on the first call if they are not. Nothing in the app was calling it, so
/// the PDF-to-Word verify screen showed that exception where the original-PDF
/// preview should have been, and the inline PDF editor would have failed the
/// same way. (8 Oct 2026)
///
/// This lives here, called from each page that opens a document, rather than
/// in main(). Both of those pages are loaded as deferred chunks; importing
/// pdfrx from main() instead would pull PDFium into the initial bundle that
/// every visitor downloads, including the ones who never touch a PDF tool.
///
/// Call it immediately before the first `PdfDocument.open*` in any new page
/// that uses pdfrx — repeat calls are free.
void ensurePdfrxInitialized() {
  if (_initialized) {
    return;
  }
  pdfrxFlutterInitialize();
  _initialized = true;
}
