ARG PYTHON_VERSION=3.14.8
FROM docker.io/library/python:${PYTHON_VERSION}-slim

ARG OPENCODE_VERSION=2.2.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs npm wamerican \
    && npm install -g "@opencode/cli@${OPENCODE_VERSION}" \
    && rm -rf /var/lib/apt/lists/* /root/.npm

COPY opencode2-wrapper.sh /usr/local/bin/opencode
RUN chmod +x /usr/local/bin/opencode && opencode --version

WORKDIR /app

# Official MTC3 data (mtc3-schmeh-09-M138-01-en.pdf and stripset download).
COPY stripset.txt /app/stripset.txt
COPY challenge.txt /app/challenge.txt
