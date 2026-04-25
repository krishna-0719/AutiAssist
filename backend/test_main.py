"""Basic API endpoint tests (requires running server)."""

import json
import os
import urllib.error
import urllib.request

import pytest


BASE = "http://localhost:7860"


def _server_available() -> bool:
    try:
        urllib.request.urlopen(f"{BASE}/health", timeout=1.5)
        return True
    except (urllib.error.URLError, TimeoutError):
        return False


if os.getenv("RUN_LIVE_BACKEND_TESTS") != "1":
    pytestmark = pytest.mark.skip(
        reason="Live backend tests are disabled. Set RUN_LIVE_BACKEND_TESTS=1 to enable."
    )
elif not _server_available():
    pytestmark = pytest.mark.skip(
        reason=f"Backend server is not reachable at {BASE}."
    )


def test_health():
    req = urllib.request.urlopen(f"{BASE}/health")
    data = json.loads(req.read())
    assert data["status"] == "healthy"
    print("✅ /health passed")


def test_status():
    req = urllib.request.urlopen(f"{BASE}/status/test-family-id")
    data = json.loads(req.read())
    assert "total_taps" in data
    print("✅ /status passed")


def test_predict():
    req = urllib.request.urlopen(f"{BASE}/predict/test-family-id/kitchen")
    data = json.loads(req.read())
    assert "predictions" in data
    print("✅ /predict passed")


def test_log():
    payload = json.dumps({
        "family_id": "test-family-id",
        "user_id": "test-user",
        "symbol_type": "water",
        "room": "kitchen",
        "hour_of_day": 10,
        "day_of_week": 3,
    }).encode()
    req = urllib.request.Request(
        f"{BASE}/log",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    resp = urllib.request.urlopen(req)
    data = json.loads(resp.read())
    assert data["status"] == "logged"
    print("✅ /log passed")


if __name__ == "__main__":
    test_health()
    test_status()
    test_predict()
    # test_log()  # Uncomment when DB is connected
    print("\nAll API tests passed ✅")
