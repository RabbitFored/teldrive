# --- Stage 1: Build your custom Teldrive ---
FROM golang:1.23-bookworm AS builder

WORKDIR /app

# Copy your source code
COPY . .

# Build the binary (Compiling your changes)
# We disable CGO for a static binary that runs anywhere
ENV CGO_ENABLED=0
RUN go build -ldflags="-s -w" -o teldrive main.go

# --- Stage 2: Create the Running Container ---
FROM debian:bookworm-slim

# Install the tools we need (gettext for envsubst, ca-certificates for Telegram HTTPS)
RUN apt-get update && apt-get install -y \
    gettext-base \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary we built in Stage 1
COPY --from=builder /app/teldrive /app/teldrive

# Create the Config Template (using default public keys if you don't have your own)
# We use 'cat' to create the file directly in the image
RUN echo '[server]\n\
port = 8080\n\
\n\
[db]\n\
data-source = "${DB_URL}"\n\
prepare-stmt = false\n\
\n\
[jwt]\n\
secret = "${JWT_SECRET}"\n\
allowed-users = [ "${ALLOWED_USER}" ]\n\
\n\
[tg.uploads]\n\
encryption-key = "${ENCRYPTION_KEY}"\n\
' > /app/config.toml.template

# Create the Startup Script
RUN echo '#!/bin/sh\n\
# Generate config.toml from Environment Variables\n\
envsubst < /app/config.toml.template > /app/config.toml\n\
echo "Config generated."\n\
\n\
# Run Teldrive\n\
/app/teldrive run\n\
' > /app/run.sh && chmod +x /app/run.sh

# Open the port
EXPOSE 8080

# Start!
CMD ["/app/run.sh"]
