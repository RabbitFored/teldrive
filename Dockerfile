# --- Stage 1: Build the Custom Binary ---
FROM golang:1.23-bookworm AS builder

WORKDIR /app

# Install unzip to handle UI assets
RUN apt-get update && apt-get install -y unzip

# 1. Copy source code
COPY . .

# 2. Download and Extract the UI Assets (Crucial Step!)
# We fetch the latest pre-built UI from the official repo so we don't have to build it ourselves
ADD https://github.com/tgdrive/teldrive-ui/releases/download/latest/teldrive-ui.zip /tmp/ui.zip
RUN unzip /tmp/ui.zip -d ui/dist

# 3. Build the Go Binary
# We disable CGO to make a static binary that works everywhere
ENV CGO_ENABLED=0
# -ldflags="-s -w" makes the binary smaller
RUN go build -ldflags="-s -w" -o teldrive main.go

# --- Stage 2: Create the Running Container ---
# We use 'debian:bookworm-slim' instead of 'scratch' so we have a shell for our script
FROM debian:bookworm-slim

# Install necessary runtime tools
# ca-certificates: Needed to talk to Telegram HTTPS API
# gettext-base: Needed for 'envsubst' to replace secrets
RUN apt-get update && apt-get install -y \
    ca-certificates \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary we built in Stage 1
COPY --from=builder /app/teldrive /app/teldrive

# Create the Config Template
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
# 1. Generate config.toml from CapRover Env Vars\n\
envsubst < /app/config.toml.template > /app/config.toml\n\
echo "Config generated successfully."\n\
\n\
# 2. Run Teldrive\n\
/app/teldrive run\n\
' > /app/run.sh && chmod +x /app/run.sh

# Open the port
EXPOSE 8080

# Start the app using our script
CMD ["/app/run.sh"]
