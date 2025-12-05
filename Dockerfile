FROM ghcr.io/tgdrive/teldrive:latest

USER root
RUN apt-get update && apt-get install -y gettext-base && rm -rf /var/lib/apt/lists/*

# Create a simpler template that uses the default API ID/Hash automatically
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

RUN echo '#!/bin/sh\n\
envsubst < /app/config.toml.template > /app/config.toml\n\
/app/teldrive run\n\
' > /app/run.sh && chmod +x /app/run.sh

CMD ["/app/run.sh"]
