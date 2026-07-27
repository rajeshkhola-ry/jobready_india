import io
import os
import tempfile

from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import fitz
from PIL import Image

try:
    from pdf2docx import Converter
except Exception:  # pragma: no cover - optional at runtime on free tier bootstrap
    Converter = None


app = Flask(__name__)
CORS(app)


def _parse_quality(raw_value: str | None, default: int = 60) -> int:
    try:
        quality = int(raw_value or default)
    except (TypeError, ValueError):
        return default
    return max(35, min(90, quality))


def _parse_max_dimension(raw_value: str | None, default: int = 1920) -> int:
    try:
        value = int(raw_value or default)
    except (TypeError, ValueError):
        return default
    return max(720, min(2400, value))


@app.get("/api/info")
def api_info():
    return jsonify(
        {
            "status": "running",
            "service": "render-python-compression-api",
            "pdfCompression": True,
            "pdfToWord": Converter is not None,
        }
    )


@app.get("/healthz")
def healthz():
    return jsonify({"ok": True})


@app.post("/compress-pdf")
@app.post("/api/compress")
def compress_pdf():
    if "file" not in request.files:
        return jsonify({"success": False, "error": "No file uploaded"}), 400

    upload = request.files["file"]
    if not upload.filename.lower().endswith(".pdf"):
        return jsonify({"success": False, "error": "Only PDF files are supported"}), 400

    quality = _parse_quality(request.form.get("quality"), default=60)
    max_dimension = _parse_max_dimension(request.form.get("max_dimension"), default=1920)

    try:
        input_bytes = upload.read()
        document = fitz.open(stream=input_bytes, filetype="pdf")
    except Exception as exc:
        return jsonify({"success": False, "error": f"Invalid or corrupted file: {exc}"}), 400

    try:
        replaced_images = 0
        for page in document:
            for image_info in page.get_images(full=True):
                xref = image_info[0]
                try:
                    extracted = document.extract_image(xref)
                    image_bytes = extracted.get("image")
                    image_ext = (extracted.get("ext") or "").lower()
                    if not image_bytes or image_ext not in {"png", "jpg", "jpeg", "jpx", "jp2"}:
                        continue

                    image = Image.open(io.BytesIO(image_bytes))
                    image.load()
                    image = image.convert("RGB")

                    if image.width > max_dimension or image.height > max_dimension:
                        image.thumbnail((max_dimension, max_dimension))

                    output = io.BytesIO()
                    image.save(output, format="JPEG", quality=quality, optimize=True)
                    optimized = output.getvalue()

                    if len(optimized) < len(image_bytes):
                        document.update_stream(xref, optimized)
                        replaced_images += 1
                except Exception:
                    continue

        compressed = io.BytesIO()
        document.save(
            compressed,
            garbage=4,
            clean=True,
            deflate=True,
            deflate_images=True,
            deflate_fonts=True,
        )
        document.close()
        compressed.seek(0)

        headers = {
            "X-Compression-Replaced-Images": str(replaced_images),
            "X-Original-Bytes": str(len(input_bytes)),
            "X-Compressed-Bytes": str(len(compressed.getvalue())),
        }
        response = send_file(
            compressed,
            mimetype="application/pdf",
            as_attachment=True,
            download_name="compressed.pdf",
        )
        response.headers.extend(headers)
        return response
    except Exception as exc:
        try:
            document.close()
        except Exception:
            pass
        return jsonify({"success": False, "error": f"Compression failed: {exc}"}), 500


@app.post("/pdf-to-word")
def pdf_to_word():
    if Converter is None:
        return jsonify({"success": False, "error": "pdf2docx is not installed on this deployment"}), 503

    if "file" not in request.files:
        return jsonify({"success": False, "error": "No file uploaded"}), 400

    upload = request.files["file"]
    temp_pdf = tempfile.NamedTemporaryFile(delete=False, suffix=".pdf")
    temp_docx = tempfile.NamedTemporaryFile(delete=False, suffix=".docx")
    temp_pdf.close()
    temp_docx.close()

    try:
        upload.save(temp_pdf.name)
        converter = Converter(temp_pdf.name)
        converter.convert(temp_docx.name, start=0, end=None)
        converter.close()

        return send_file(
            temp_docx.name,
            mimetype="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            as_attachment=True,
            download_name="converted.docx",
        )
    except Exception as exc:
        return jsonify({"success": False, "error": f"Conversion failed: {exc}"}), 500
    finally:
        for path in (temp_pdf.name, temp_docx.name):
            if os.path.exists(path):
                os.remove(path)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
