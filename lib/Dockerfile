FROM node:18-bullseye-slim

WORKDIR /app

# Install system dependencies:
#  - ghostscript: PDF->JPEG conversion and multi-pass PDF compression
#  - libreoffice-writer + libreoffice-impress: headless PDF -> DOCX structural conversion
#    (fallback engine; preserves tables/layout/fonts far better than image embedding or
#    plain text extraction)
#  - imagemagick: lightweight deskew + auto-contrast pass on rasterized PDF pages before
#    any downstream OCR/text-extraction
#  - python3/pip/setuptools: runtime for pdf2docx, the primary (highest-fidelity) PDF ->
#    DOCX engine
#  - fonts-liberation: metric-compatible substitutes for Arial/Times New Roman/Courier New
#    (the standard Debian equivalent to the proprietary MS core fonts, with no external
#    network fetch required at build time)
#  - fonts-dejavu-core/fonts-noto-core/fonts-noto-cjk/fonts-freefont-ttf: broaden Unicode/
#    CJK/regional glyph coverage so converted documents keep correct font rendering
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ghostscript \
    imagemagick \
    libreoffice-writer \
    libreoffice-impress \
    python3 \
    python3-pip \
    python3-setuptools \
    fonts-liberation \
    fonts-dejavu-core \
    fonts-noto-cjk \
    fonts-noto-core \
    fonts-freefont-ttf \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install pdf2docx (Python/PyMuPDF-based) for high-fidelity PDF -> DOCX conversion: real
# table bounding-box detection, multi-column text flow, and embedded shapes - tried before
# the headless LibreOffice fallback.
RUN pip3 install --no-cache-dir pdf2docx

# Verify ghostscript, LibreOffice, ImageMagick and pdf2docx installation
RUN which gs && gs --version
RUN which soffice && soffice --version
RUN which convert && convert --version
RUN which pdf2docx

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application files
COPY compression_server.js .
COPY public/ ./public/

# Create upload directory
RUN mkdir -p temp_uploads logs && chmod 777 temp_uploads logs

# Expose port
EXPOSE 3000

# Health check using node (compatible with Debian)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/info', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# Start application
CMD ["node", "compression_server.js"]
