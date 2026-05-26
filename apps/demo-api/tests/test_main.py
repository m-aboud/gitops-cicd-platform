"""Tests for demo-api."""
from __future__ import annotations

import os

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    # Ensure deterministic behaviour
    os.environ["APP_VERSION"] = "test"
    os.environ["FAIL_RATE"] = "0.0"
    from app.main import app
    return TestClient(app)


def test_healthz(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_readyz(client):
    r = client.get("/readyz")
    assert r.status_code == 200


def test_version(client):
    r = client.get("/version")
    assert r.status_code == 200
    assert r.json()["version"] == "test"


def test_work_succeeds(client):
    r = client.get("/work")
    assert r.status_code == 200
    body = r.json()
    assert 1 <= body["result"] <= 100
    assert body["version"] == "test"


def test_metrics_endpoint_exposed(client):
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "demo_api_requests_total" in r.text
