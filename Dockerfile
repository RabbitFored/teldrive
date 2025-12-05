# --- Stage 1: Build the Custom Binary ---
# We use Go 1.25 to support the 'tool' directive and new features
FROM golang:1.25-bookworm AS builder

WORKDIR /app

# Install unzip (for UI) and Task (for build automation)
RUN apt-get update && apt-get install -y unzip && \
    go install github.com/go-task/task/v3/cmd/task@latest

# 1. Copy source code
COPY . .

# 2. Download and Extract UI Assets
# (Required so the website isn't blank)
ADD https://github.com/tgdrive/teldrive-ui/releases/latest/download/teldrive-ui.zip /tmp/ui.zip
RUN unzip -o /tmp/ui.zip -d ui/dist

# 3. Generate Missing Code (The Fix!)
# This creates the 'internal/api' folder and other missing files
RUN go mod download
RUN go generate ./...

# 4. Build the Binary
ENV CGO_ENABLED=0
RUN go build -ldflags="-s -w" -o teldrive main.go

# --- Stage 2: Create the Running Container ---
FROM debian:bookworm-slim

# Runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary we built
COPY --from=builder /app/teldrive /app/teldrive

# Create Config Template
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

# Create Startup Script
RUN echo '#!/bin/sh\n\
envsubst < /app/config.toml.template > /app/config.toml\n\
/app/teldrive run\n\
' > /app/run.sh && chmod +x /app/run.sh

EXPOSE 8080
CMD ["/app/run.sh"]
