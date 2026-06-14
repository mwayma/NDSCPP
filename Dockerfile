# Stage 1: Build C++ Backend (NDSCPP)
FROM ubuntu:24.04 AS backend-builder
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    clang \
    make \
    libasio-dev \
    zlib1g-dev \
    libavformat-dev \
    libavcodec-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libcurl4-gnutls-dev \
    libspdlog-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

# Build the C++ application (Make will also copy the .example files to their required locations)
RUN make -j$(nproc)

# Stage 2: Build Angular Frontend (NDSWeb)
FROM node:22-bullseye-slim AS frontend-builder
WORKDIR /app

# Copy the frontend workspace and install dependencies
COPY ndsweb/package*.json ./
RUN npm ci --legacy-peer-deps

COPY ndsweb/ ./
# Modify the APP_SERVER_URL so it routes to our local reverse proxy instead of localhost:7777
RUN sed -i "s|http://localhost:7777/api|/api|g" src/app/app.config.ts

# Build the Angular application
RUN npx nx build monitor-web --configuration=production

# Stage 3: Final runtime image
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies, Nginx, and Supervisor
RUN apt-get update && apt-get install -y \
    zlib1g \
    libavformat-dev \
    libavcodec-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libcurl4-gnutls-dev \
    libspdlog-dev \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Setup Nginx as a reverse proxy (serves Angular on /, proxies /api to ndscpp on 7777)
RUN echo 'server { \n\
    listen 80; \n\
    server_name localhost; \n\
    \n\
    location / { \n\
        root /var/www/html; \n\
        index index.html; \n\
        try_files $uri $uri/ /index.html; \n\
    } \n\
    \n\
    location /api/ { \n\
        proxy_pass http://127.0.0.1:7777/api/; \n\
        proxy_set_header Host $host; \n\
        proxy_set_header X-Real-IP $remote_addr; \n\
    } \n\
}' > /etc/nginx/sites-available/default

# Setup Supervisor to run both Nginx and ndscpp
RUN echo '[supervisord]\n\
nodaemon=true\n\
\n\
[program:nginx]\n\
command=nginx -g "daemon off;"\n\
autostart=true\n\
autorestart=true\n\
\n\
[program:ndscpp]\n\
command=/app/ndscpp\n\
directory=/app\n\
autostart=true\n\
autorestart=true' > /etc/supervisor/conf.d/supervisord.conf

WORKDIR /app

# Copy compiled backend binary and required config files
COPY --from=backend-builder /src/ndscpp .
COPY --from=backend-builder /src/config.led .
COPY --from=backend-builder /src/secrets.h .
COPY --from=backend-builder /src/sample_config.json .
COPY --from=backend-builder /src/media ./media

# Copy compiled frontend assets to Nginx html directory
COPY --from=frontend-builder /app/dist/monitor-web /var/www/html

# Expose port 80 for the Nginx server
EXPOSE 80

# Start supervisor which manages nginx and ndscpp
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
