import base64
import hashlib
import hmac
import io
import json
import os
import tempfile
import urllib.error
import urllib.request

from flask import Flask, Response, jsonify, request, send_file
from flask_cors import CORS
import fitz
from PIL import Image
from anthropic import Anthropic

try:
    from pdf2docx import Converter
except Exception:  # pragma: no cover - optional at runtime on free tier bootstrap
    Converter = None


app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}})

# Anthropic Client for Druta AI Agent
def _get_anthropic_client():
    api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if not api_key:
        return None
    return Anthropic(api_key=api_key)


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


def _razorpay_key_id() -> str:
    return os.environ.get("RAZORPAY_KEY_ID", "").strip()


def _razorpay_key_secret() -> str:
    return os.environ.get("RAZORPAY_KEY_SECRET", "").strip()


def _razorpay_payment_link_enabled() -> bool:
    return bool(_razorpay_key_id() and _razorpay_key_secret())


def _plan_name(plan_id: str) -> str:
    normalized = (plan_id or "").strip().lower()
    return {
        "free": "Free",
        "7days": "7 Days",
        "monthly": "Monthly",
        "yearly": "Yearly",
        "lifetime": "Lifetime Launch Offer",
        "lifetime-pro": "Lifetime Pro",
    }.get(normalized, "Lifetime Pro")


def _local_checkout_response(plan_id: str, amount: int, currency: str, receipt: str, *, payment_link: bool = False):
    timestamp = int(__import__('time').time() * 1000)
    normalized_currency = str(currency or "INR").upper()
    normalized_plan = str(plan_id or "Lifetime").strip() or "Lifetime"
    reference_id = f"{'plink' if payment_link else 'local-order'}-{timestamp}"

    if payment_link:
        return {
            "success": True,
            "provider": "local",
            "localOnly": True,
            "reference_id": reference_id,
            "link_id": f"local-{timestamp}",
            "payment_link": "https://getreadyjob.com/#pricing",
            "status": "local_created",
            "amount": int(amount),
            "currency": normalized_currency,
            "plan_id": normalized_plan,
            "plan_name": _plan_name(normalized_plan),
        }

    return {
        "success": True,
        "provider": "local",
        "localOnly": True,
        "order_id": reference_id,
        "amount": int(amount),
        "currency": normalized_currency,
        "status": "local_created",
        "receipt": receipt,
        "plan_id": normalized_plan,
    }


def _post_razorpay_json(url: str, payload: dict) -> dict:
    credentials = f"{_razorpay_key_id()}:{_razorpay_key_secret()}".encode("utf-8")
    request_payload = json.dumps(payload).encode("utf-8")
    http_request = urllib.request.Request(
        url,
        data=request_payload,
        method="POST",
        headers={
            "Authorization": f"Basic {base64.b64encode(credentials).decode('ascii')}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(http_request, timeout=30) as response:
            body = response.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8") if exc.fp else ""
        detail = body
        try:
            parsed = json.loads(body) if body else {}
            detail = parsed.get("error", {}).get("description") or parsed.get("description") or body
        except Exception:
            pass
        raise RuntimeError(detail or f"Razorpay request failed with HTTP {exc.code}") from exc


def _get_razorpay_json(url: str) -> dict:
    credentials = f"{_razorpay_key_id()}:{_razorpay_key_secret()}".encode("utf-8")
    http_request = urllib.request.Request(
        url,
        method="GET",
        headers={
            "Authorization": f"Basic {base64.b64encode(credentials).decode('ascii')}",
            "Accept": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(http_request, timeout=30) as response:
            body = response.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8") if exc.fp else ""
        detail = body
        try:
            parsed = json.loads(body) if body else {}
            detail = parsed.get("error", {}).get("description") or parsed.get("description") or body
        except Exception:
            pass
        raise RuntimeError(detail or f"Razorpay request failed with HTTP {exc.code}") from exc


# ==========================================
# DRUTA AI AGENT API ROUTE (STREAMING)
# ==========================================
@app.post("/api/druta-agent")
def druta_agent():
    client = _get_anthropic_client()
    if not client:
        return jsonify({"success": False, "error": "ANTHROPIC_API_KEY is not configured on server."}), 500

    payload = request.get_json(silent=True) or {}
    messages = payload.get("messages", [])
    system_prompt = payload.get("systemPrompt", "You are Druta AI, an elite software architect and full-stack coding agent built by Druta Systems.")

    if not messages:
        return jsonify({"success": False, "error": "Messages array cannot be empty."}), 400

    def generate():
        try:
            with client.messages.stream(
                model="claude-3-5-sonnet-latest",
                max_tokens=8192,
                system=system_prompt,
                messages=messages
            ) as stream:
                for text in stream.text_stream:
                    yield f"data: {json.dumps({'text': text})}\n\n"
            yield "data: [DONE]\n\n"
        except Exception as exc:
            yield f"data: {json.dumps({'error': str(exc)})}\n\n"

    return Response(generate(), mimetype="text/event-stream")


@app.get("/api/config")
def api_config():
    return jsonify(
        {
            "key_id": _razorpay_key_id(),
            "gateway": "razorpay",
            "payment_link_enabled": _razorpay_payment_link_enabled(),
        }
    )


@app.post("/api/create-payment-link")
def create_payment_link():
    payload = request.get_json(silent=True) or {}
    amount = payload.get("amount")
    try:
        amount = int(amount)
    except (TypeError, ValueError):
        amount = 0

    if amount <= 0:
        return jsonify({"success": False, "error": "Amount must be greater than zero."}), 400

    currency = str(payload.get("currency") or "INR").upper()
    plan_id = str(payload.get("planId") or "Lifetime").strip() or "Lifetime"
    receipt = str(payload.get("receipt") or f"payment-link-{int(__import__('time').time() * 1000)}")
    billing = payload.get("billing") if isinstance(payload.get("billing"), dict) else {}

    customer_name = str(billing.get("name") or payload.get("name") or "User").strip() or "User"
    customer_email = str(billing.get("email") or payload.get("email") or "").strip()
    customer_phone = "".join(ch for ch in str(billing.get("mobile") or payload.get("mobile") or "") if ch.isdigit())
    reference_id = f"plink-{int(__import__('time').time() * 1000)}"

    if not _razorpay_payment_link_enabled():
        return jsonify(_local_checkout_response(plan_id, amount, currency, receipt, payment_link=True)), 200

    razorpay_payload = {
        "amount": amount,
        "currency": currency,
        "reference_id": reference_id,
        "description": f"GetReadyJob {_plan_name(plan_id)} payment",
        "customer": {
            "name": customer_name,
            **({"email": customer_email} if customer_email else {}),
            **({"contact": customer_phone} if customer_phone else {}),
        },
        "notify": {
            "sms": bool(customer_phone),
            "email": bool(customer_email),
        },
        "reminder_enable": True,
        "notes": {
            "plan_id": plan_id,
            "receipt": receipt,
        },
    }

    callback_url = os.environ.get("RAZORPAY_CALLBACK_URL", "").strip()
    if callback_url:
        razorpay_payload["callback_url"] = callback_url
        razorpay_payload["callback_method"] = "get"

    try:
        link = _post_razorpay_json("https://api.razorpay.com/v1/payment_links", razorpay_payload)
    except RuntimeError as exc:
        error_text = str(exc).lower()
        if any(token in error_text for token in ("authentication failed", "unauthorized", "bad request", "api key", "not configured", "invalid key")):
            return jsonify(_local_checkout_response(plan_id, amount, currency, receipt, payment_link=True)), 200
        return jsonify({"success": False, "error": str(exc)}), 400
    except Exception as exc:
        error_text = str(exc).lower()
        if any(token in error_text for token in ("authentication failed", "unauthorized", "bad request", "api key", "not configured", "invalid key")):
            return jsonify(_local_checkout_response(plan_id, amount, currency, receipt, payment_link=True)), 200
        return jsonify({"success": False, "error": f"Unable to create Razorpay payment link: {exc}"}), 500

    return jsonify(
        {
            "success": True,
            "provider": "razorpay",
            "reference_id": reference_id,
            "link_id": link.get("id", ""),
            "payment_link": link.get("short_url", ""),
            "status": link.get("status", "created"),
            "amount": amount,
            "currency": currency,
            "plan_id": plan_id,
            "plan_name": _plan_name(plan_id),
            "expires_at": link.get("expire_by"),
        }
    )


@app.post("/api/create-order")
def create_order():
    payload = request.get_json(silent=True) or {}
    amount = payload.get("amount")
    try:
        amount = int(amount)
    except (TypeError, ValueError):
        amount = 0

    if amount <= 0:
        return jsonify({"success": False, "error": "Amount must be greater than zero."}), 400

    currency = str(payload.get("currency") or "INR").upper()
    receipt = str(payload.get("receipt") or f"order-{int(__import__('time').time() * 1000)}")
    plan_id = str(payload.get("planId") or payload.get("plan_id") or "Lifetime").strip() or "Lifetime"
    usage_type = str(payload.get("usageType") or payload.get("usage_type") or "personal").strip() or "personal"

    if not _razorpay_payment_link_enabled():
        return jsonify(_local_checkout_response(plan_id, amount, currency, receipt)), 200

    razorpay_payload = {
        "amount": amount,
        "currency": currency,
        "receipt": receipt,
        "notes": {
            "plan_id": plan_id,
            "usage_type": usage_type,
        },
    }

    try:
        order = _post_razorpay_json("https://api.razorpay.com/v1/orders", razorpay_payload)
    except RuntimeError as exc:
        error_text = str(exc).lower()
        if any(token in error_text for token in ("authentication failed", "unauthorized", "bad request", "api key", "not configured", "invalid key")):
            return jsonify(_local_checkout_response(plan_id, amount, currency, receipt)), 200
        return jsonify({"success": False, "error": str(exc)}), 400
    except Exception as exc:
        error_text = str(exc).lower()
        if any(token in error_text for token in ("authentication failed", "unauthorized", "bad request", "api key", "not configured", "invalid key")):
            return jsonify(_local_checkout_response(plan_id, amount, currency, receipt)), 200
        return jsonify({"success": False, "error": f"Unable to create Razorpay order: {exc}"}), 500

    return jsonify(
        {
            "success": True,
            "provider": "razorpay",
            "order_id": order.get("id", ""),
            "amount": order.get("amount", amount),
            "currency": order.get("currency", currency),
            "status": order.get("status", "created"),
            "receipt": order.get("receipt", receipt),
        }
    )


@app.post("/api/verify-payment")
def verify_payment():
    if not _razorpay_payment_link_enabled():
        return (
            jsonify(
                {
                    "success": False,
                    "error": "Razorpay checkout is not configured on server. Please set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET.",
                }
            ),
            503,
        )

    payload = request.get_json(silent=True) or {}
    order_id = str(payload.get("order_id") or "").strip()
    payment_id = str(payload.get("payment_id") or "").strip()
    signature = str(payload.get("signature") or "").strip()

    if not order_id or not payment_id or not signature:
        return jsonify({"success": False, "error": "order_id, payment_id and signature are required."}), 400

    message = f"{order_id}|{payment_id}".encode("utf-8")
    expected_signature = hmac.new(
        _razorpay_key_secret().encode("utf-8"),
        message,
        hashlib.sha256,
    ).hexdigest()

    if not hmac.compare_digest(expected_signature, signature):
        return jsonify({"success": False, "error": "Invalid payment signature."}), 400

    payment_status = "unknown"
    amount = None
    currency = None
    try:
        payment = _get_razorpay_json(f"https://api.razorpay.com/v1/payments/{payment_id}")
        payment_status = str(payment.get("status") or "unknown")
        amount = payment.get("amount")
        currency = payment.get("currency")
    except Exception:
        pass

    return jsonify(
        {
            "success": True,
            "verified": True,
            "provider": "razorpay",
            "order_id": order_id,
            "payment_id": payment_id,
            "payment_status": payment_status,
            "amount": amount,
            "currency": currency,
        }
    )


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