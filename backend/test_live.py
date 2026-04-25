import os
import time

import pytest
import requests

BASE_URL = "http://localhost:7860"
FAMILY_ID = "test-family-123"


def _server_available() -> bool:
    try:
        resp = requests.get(f"{BASE_URL}/health", timeout=1.5)
        return resp.status_code == 200
    except requests.RequestException:
        return False


if os.getenv("RUN_LIVE_BACKEND_TESTS") != "1":
    pytestmark = pytest.mark.skip(
        reason="Live backend tests are disabled. Set RUN_LIVE_BACKEND_TESTS=1 to enable."
    )
elif not _server_available():
    pytestmark = pytest.mark.skip(
        reason=f"Backend server is not reachable at {BASE_URL}."
    )


def test_live_training_flow():
    resp = requests.get(f"{BASE_URL}/health", timeout=3)
    assert resp.status_code == 200

    for i in range(25):
        data = {
            "family_id": FAMILY_ID,
            "symbol_type": "water" if i % 2 == 0 else "food",
            "room": "Kitchen",
            "hour_of_day": 12,
            "day_of_week": 1,
        }
        post_resp = requests.post(f"{BASE_URL}/log", json=data, timeout=3)
        assert post_resp.status_code in (200, 201)

    train_resp = requests.post(f"{BASE_URL}/train/{FAMILY_ID}", timeout=5)
    assert train_resp.status_code == 200

    time.sleep(2)

    status_resp = requests.get(f"{BASE_URL}/status/{FAMILY_ID}", timeout=5)
    assert status_resp.status_code == 200
    assert "total_taps" in status_resp.json()

    pred_resp = requests.get(
        f"{BASE_URL}/predict/{FAMILY_ID}/Kitchen?hour=12&day=1",
        timeout=5,
    )
    assert pred_resp.status_code == 200
    assert "predictions" in pred_resp.json()

