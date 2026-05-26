"""Demo API — minimal FastAPI service used to exercise the CI/CD pipeline.

Exposes /healthz, /readyz, /version, /work endpoints.
"""
from __future__ import annotations

import os
import random
import time
from typing import Any

from fastapi import FastAPI, HTTPException
from prometheus_client import Counter, Histogram, make_asgi_app

VERSION = os.getenv("APP_VERSION", "dev")
GREETING = os.getenv("GREETING", "Hello from demo-api")
FAIL_RATE = float(os.getenv("FAIL_RATE", "0.0"))  # used by canary analysis demo

REQUESTS = Counter("demo_api_requests_total", "Total requests", ["endpoint", "status"])
LATENCY = Histogram("demo_api_request_latency_seconds", "Request latency", ["endpoint"])

app = FastAPI(title="demo-api", version=VERSION)
app.mount("/metrics", make_asgi_app())


@app.get("/healthz")
def healthz() -> dict[str, str]:
    REQUESTS.labels(endpoint="/healthz", status="200").inc()
    return {"status": "ok"}


@app.get("/readyz")
def readyz() -> dict[str, str]:
    REQUESTS.labels(endpoint="/readyz", status="200").inc()
    return {"status": "ready"}


@app.get("/version")
def version() -> dict[str, str]:
    REQUESTS.labels(endpoint="/version", status="200").inc()
    return {"version": VERSION, "greeting": GREETING}


@app.get("/work")
def work() -> dict[str, Any]:
    """Simulates real work. Fails at FAIL_RATE — drives canary analysis."""
    with LATENCY.labels(endpoint="/work").time():
        time.sleep(random.uniform(0.01, 0.05))
        if random.random() < FAIL_RATE:
            REQUESTS.labels(endpoint="/work", status="500").inc()
            raise HTTPException(status_code=500, detail="Simulated failure")
        REQUESTS.labels(endpoint="/work", status="200").inc()
        return {"result": random.randint(1, 100), "version": VERSION}
