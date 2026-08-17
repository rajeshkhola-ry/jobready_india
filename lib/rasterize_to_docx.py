#!/usr/bin/env python3
"""Builds a Word (.docx) document with one full-page image per page.

Usage: rasterize_to_docx.py <output.docx> <image1> [<image2> ...]

Final "Tier 3" fallback for scanned/image-only PDFs where neither
pdf2docx nor LibreOffice's native PDF import could produce a usable
DOCX. Uses python-docx directly instead of LibreOffice's HTML import,
which can fail to embed file:// or relative image URIs in headless
mode - this guarantees the images are actually embedded.
Prints a JSON result to stdout: {"success": true, "pages": N} or
{"error": "<message>"}.
"""

import sys
import json

try:
    from docx import Document
    from docx.shared import Inches
    from docx.enum.text import WD_BREAK
except ImportError as exc:
    print(json.dumps({'error': 'python-docx not installed: ' + str(exc)}))
    sys.exit(1)

PAGE_IMAGE_WIDTH_INCHES = 6.5


def main():
    if len(sys.argv) < 3:
        print(json.dumps({'error': 'Usage: rasterize_to_docx.py <output.docx> <image1> [<image2> ...]'}))
        sys.exit(1)

    output_path = sys.argv[1]
    image_paths = sys.argv[2:]

    try:
        document = Document()
        for index, image_path in enumerate(image_paths):
            paragraph = document.add_paragraph()
            run = paragraph.add_run()
            run.add_picture(image_path, width=Inches(PAGE_IMAGE_WIDTH_INCHES))
            if index < len(image_paths) - 1:
                paragraph.add_run().add_break(WD_BREAK.PAGE)

        document.save(output_path)
    except Exception as exc:
        print(json.dumps({'error': 'Failed to build DOCX: ' + str(exc)}))
        sys.exit(1)

    print(json.dumps({'success': True, 'pages': len(image_paths)}))


if __name__ == '__main__':
    main()
