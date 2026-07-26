FROM node:18-alpine

WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl

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

# Health check using node (compatible with alpine)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/info', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"

# Start application
CMD ["node", "compression_server.js"]
