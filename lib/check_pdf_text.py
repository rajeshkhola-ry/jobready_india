#!/usr/bin/env python3
"""Quickly checks whether a PDF has meaningful selectable text.

Usage: check_pdf_text.py <input.pdf>

Used to fast-path scanned/image-only PDFs directly to the rasterized-image
DOCX fallback (Tier 3), skipping the pdf2docx/LibreOffice tiers that are
guaranteed to fail on a pure scan anyway - avoids wasting 40-150s of wall
clock and a full LibreOffice process spawn on documents with no text layer.
Uses PyMuPDF (fitz), already installed as pdf2docx's own PDF-parsing
dependency, so no new package is required.

Prints JSON to stdout:
  {"hasText": bool, "textLength": N, "pageCount": N, "sampledPages": N}
or, if the check itself could not run:
  {"error": "<message>"}
Callers must fail open (treat a failed check as "has text") so a broken
check never prevents the normal, higher-fidelity tier chain from running.
"""

import sys
import json

try:
    import fitz  # PyMuPDF
except ImportError as exc:
    print(json.dumps({'error': 'PyMuPDF (fitz) not installed: ' + str(exc)}))
    sys.exit(1)

# Real body text runs to hundreds/thousands of characters per page - a pure
# scan has zero (or a stray watermark/metadata sliver). Averaging across
# sampled pages keeps this scale-invariant for both short and long documents.
MIN_AVERAGE_CHARS_PER_PAGE = 15
MAX_PAGES_TO_SAMPLE = 40


def main():
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'Usage: check_pdf_text.py <input.pdf>'}))
        sys.exit(1)

    input_path = sys.argv[1]

    try:
        document = fitz.open(input_path)
        page_count = document.page_count
        sample_count = min(page_count, MAX_PAGES_TO_SAMPLE)
        text_length = 0
        for page_index in range(sample_count):
            page = document.load_page(page_index)
            text_length += len(page.get_text('text').strip())
        document.close()
    except Exception as exc:
        print(json.dumps({'error': 'Could not inspect PDF text content: ' + str(exc)}))
        sys.exit(1)

    average_chars = (text_length / sample_count) if sample_count else 0
    print(json.dumps({
        'hasText': average_chars >= MIN_AVERAGE_CHARS_PER_PAGE,
        'textLength': text_length,
        'pageCount': page_count,
        'sampledPages': sample_count
    }))


if __name__ == '__main__':
    main()
