ARG PYTHON_VERSION=3.14.8
FROM docker.io/library/python:${PYTHON_VERSION}-slim

ARG OPENCODE_VERSION=2.2.2

# Preinstall OpenCode 2 so the custom Harbor agent can skip the repeated
# OpenCode 1 installation. npm is only needed while building this image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs npm \
    && npm install -g "@opencode/cli@${OPENCODE_VERSION}" \
    && rm -rf /var/lib/apt/lists/* /root/.npm

COPY opencode2-wrapper.sh /usr/local/bin/opencode
RUN chmod +x /usr/local/bin/opencode && opencode --version

WORKDIR /app

# The challenge ciphertext (MTC3, mtc3-esslinger-05-caesar.txt), unmodified.
COPY ciphertext.txt /app/ciphertext.txt
