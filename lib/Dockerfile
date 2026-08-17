FROM node:18-bullseye-slim

WORKDIR /app

# Install system dependencies:
#  - ghostscript: PDF->JPEG conversion and multi-pass PDF compression
#  - libreoffice-writer + libreoffice-impress: headless PDF -> DOCX structural conversion
#    (preserves tables/layout/fonts far better than image embedding or plain text extraction)
#  - fonts-liberation: metric-compatible substitutes for common Word fonts so converted
#    documents keep sane line-wrapping/pagination even when the original fonts aren't embedded
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ghostscript \
    libreoffice-writer \
    libreoffice-impress \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Verify ghostscript and LibreOffice installation
RUN which gs && gs --version
RUN which soffice && soffice --version

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
