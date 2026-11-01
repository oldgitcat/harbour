ARG PYTHON_VERSION=3.14.8
FROM docker.io/library/python:${PYTHON_VERSION}-slim

ARG HARBOR_VERSION=0.25.0
ARG PODMAN_COMPOSE_VERSION=1.6.0

COPY requirements.lock /tmp/requirements.lock

RUN apt-get update \
    && apt-get install -y --no-install-recommends podman-remote \
    && ln -s /usr/bin/podman-remote /usr/local/bin/podman \
    && pip install --no-cache-dir \
        -r /tmp/requirements.lock \
        "harbor==${HARBOR_VERSION}" \
        "podman-compose==${PODMAN_COMPOSE_VERSION}" \
    && harbor --version \
    && podman --version \
    && podman-compose version \
    && rm -rf /var/lib/apt/lists/*

COPY local/opencode2_agent.py /opt/harbor/agent/opencode2_agent.py
COPY local/analyze_job.py /opt/harbor/agent/analyze_job.py
COPY local/containers.conf /etc/containers/containers.conf
COPY local/harbor-entrypoint.sh /usr/local/bin/harbor-entrypoint
RUN chmod +x /usr/local/bin/harbor-entrypoint

ENV CONTAINER_HOST=unix:///run/podman/podman.sock \
    DOCKER_HOST=unix:///run/podman/podman.sock \
    PODMAN_COMPOSE_WARNING_LOGS=false \
    PYTHONPATH=/opt/harbor/agent

ENTRYPOINT ["harbor-entrypoint"]
CMD ["--help"]
