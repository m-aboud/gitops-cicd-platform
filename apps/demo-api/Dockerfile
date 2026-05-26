# syntax=docker/dockerfile:1.7
#
# Multi-stage build:
#   1. builder — install deps into a venv
#   2. runtime — distroless Python, non-root, copy venv only
#
# Build:
#   docker build --build-arg APP_VERSION=1.2.3 -t demo-api:1.2.3 apps/demo-api/

# -------- builder --------
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app/ ./app/

# -------- runtime --------
FROM gcr.io/distroless/python3-debian12:nonroot

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH=/app

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /build/app /app/app

USER nonroot:nonroot

EXPOSE 8000

# OCI labels for provenance traceability
LABEL org.opencontainers.image.title="demo-api" \
      org.opencontainers.image.description="Demo API for the GitOps CI/CD platform" \
      org.opencontainers.image.source="https://github.com/mohammedabood/gitops-cicd-platform" \
      org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/opt/venv/bin/python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
