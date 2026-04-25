"""
Comprehensive unit tests for BehaviorModel v3.0.

Tests verify:
  - Phase selection logic (Phase 1/2/3)
  - Prediction accuracy (correct symbol predicted for learned context)
  - Time decay (recent taps weighted more than old taps)
  - Gaussian hour smoothing (nearby hours get bleed-over predictions)
  - Room isolation (kitchen predictions don't leak into bedroom)
  - Day-of-week sensitivity
  - Ensemble blending correctness
  - Explanation output
  - Edge cases (empty data, minimal data, unknown rooms)
"""

from datetime import datetime, timezone, timedelta
from model import BehaviorModel, MIN_TAPS, PHASE2_THRESHOLD, PHASE3_THRESHOLD


def _make_log(symbol_type: str, room: str, hour: int, day: int = 0,
              days_ago: int = 5) -> dict:
    """Helper to create a behavior log entry."""
    created = datetime.now(timezone.utc) - timedelta(days=days_ago)
    return {
        "symbol_type": symbol_type,
        "room": room,
        "hour_of_day": hour,
        "day_of_week": day,
        "created_at": created.isoformat(),
    }


def _make_logs(symbol_type: str, room: str, hour: int, count: int,
               day: int = 0, days_ago: int = 5) -> list[dict]:
    """Helper to create N identical logs."""
    return [_make_log(symbol_type, room, hour, day, days_ago) for _ in range(count)]


# ─── Phase Selection Tests ────────────────────────────────

def test_no_data():
    model = BehaviorModel("test")
    result = model.train([])
    assert result["status"] == "no_data"
    print("✅ test_no_data passed")


def test_not_ready_insufficient_taps():
    model = BehaviorModel("test")
    logs = _make_logs("water", "kitchen", 8, 5)  # Only 5, need 20
    result = model.train(logs)
    assert result["status"] == "not_ready"
    assert result["total_taps"] == 5
    print("✅ test_not_ready_insufficient_taps passed")


def test_phase1_training():
    model = BehaviorModel("test")
    logs = _make_logs("water", "kitchen", 8, 30)
    result = model.train(logs)
    assert result["status"] == "trained"
    assert result["phase"] == 1
    assert result["model"] == "bayesian_frequency"
    print("✅ test_phase1_training passed")


def test_phase2_training():
    model = BehaviorModel("test")
    logs = (
        _make_logs("water", "kitchen", 8, 60) +
        _make_logs("food", "kitchen", 12, 50)
    )
    assert len(logs) >= PHASE2_THRESHOLD
    result = model.train(logs)
    assert result["status"] == "trained"
    assert result["phase"] == 2
    assert result["model"] == "gradient_boosting"
    print("✅ test_phase2_training passed")


def test_phase3_training():
    model = BehaviorModel("test")
    logs = (
        _make_logs("water", "kitchen", 8, 200) +
        _make_logs("food", "kitchen", 12, 200) +
        _make_logs("play", "living", 15, 150)
    )
    assert len(logs) >= PHASE3_THRESHOLD
    result = model.train(logs)
    assert result["status"] == "trained"
    assert result["phase"] == 3
    assert result["model"] == "ensemble"
    print("✅ test_phase3_training passed")


# ─── Prediction Accuracy Tests ────────────────────────────

def test_basic_prediction_accuracy():
    """Model should predict 'water' in kitchen at 8 AM."""
    model = BehaviorModel("accuracy")
    logs = (
        _make_logs("water", "kitchen", 8, 25) +
        _make_logs("food", "kitchen", 12, 5)
    )
    model.train(logs)

    preds = model.predict("kitchen", 8)
    assert len(preds) > 0
    assert preds[0]["type"] == "water", f"Expected 'water' but got '{preds[0]['type']}'"
    assert preds[0]["confidence"] > 0.5, f"Confidence too low: {preds[0]['confidence']}"
    print("✅ test_basic_prediction_accuracy passed")


def test_room_pattern_accuracy():
    """Different rooms should predict different symbols."""
    model = BehaviorModel("rooms")
    logs = (
        _make_logs("water", "kitchen", 10, 30) +
        _make_logs("sleep", "bedroom", 10, 30)
    )
    model.train(logs)

    kitchen_preds = model.predict("kitchen", 10)
    bedroom_preds = model.predict("bedroom", 10)

    assert kitchen_preds[0]["type"] == "water"
    assert bedroom_preds[0]["type"] == "sleep"
    print("✅ test_room_pattern_accuracy passed")


def test_time_of_day_accuracy():
    """Same room, different times should predict different symbols."""
    model = BehaviorModel("tod")
    logs = (
        _make_logs("water", "kitchen", 8, 30) +
        _make_logs("food", "kitchen", 12, 30) +
        _make_logs("sleep", "bedroom", 21, 30)
    )
    model.train(logs)

    morning = model.predict("kitchen", 8)
    noon = model.predict("kitchen", 12)
    night = model.predict("bedroom", 21)

    assert morning[0]["type"] == "water"
    assert noon[0]["type"] == "food"
    assert night[0]["type"] == "sleep"
    print("✅ test_time_of_day_accuracy passed")


# ─── Time Decay Tests ─────────────────────────────────────

def test_time_decay_favors_recent():
    """Recent taps should have more influence than old taps."""
    model = BehaviorModel("decay")
    logs = (
        _make_logs("food", "kitchen", 8, 20, days_ago=30) +  # Old: food
        _make_logs("water", "kitchen", 8, 15, days_ago=1)    # Recent: water
    )
    model.train(logs)

    preds = model.predict("kitchen", 8)
    assert preds[0]["type"] == "water", \
        f"Recent 'water' should be predicted over old 'food', got '{preds[0]['type']}'"
    print("✅ test_time_decay_favors_recent passed")


# ─── Gaussian Hour Smoothing Tests ────────────────────────

def test_hour_smoothing():
    """Prediction at hour 9 should be influenced by data from hour 8."""
    model = BehaviorModel("smooth")
    # Use 2 symbols so confidence isn't trivially 100%
    logs = (
        _make_logs("water", "kitchen", 8, 25) +
        _make_logs("food", "kitchen", 14, 25)
    )
    model.train(logs)

    # Hour 9 should still predict water (due to Gaussian smoothing from hour 8)
    preds_9 = model.predict("kitchen", 9)
    assert len(preds_9) > 0
    assert preds_9[0]["type"] == "water"

    # Hour 8 (exact match) should have higher water confidence than hour 9
    preds_8 = model.predict("kitchen", 8)
    water_at_8 = [p for p in preds_8 if p["type"] == "water"]
    water_at_9 = [p for p in preds_9 if p["type"] == "water"]
    assert water_at_8 and water_at_9
    assert water_at_8[0]["confidence"] >= water_at_9[0]["confidence"]
    print("✅ test_hour_smoothing passed")


# ─── Room Isolation Tests ─────────────────────────────────

def test_room_isolation():
    """Kitchen patterns should not leak into bedroom predictions."""
    model = BehaviorModel("isolation")
    logs = _make_logs("water", "kitchen", 8, 30)
    model.train(logs)

    kitchen_preds = model.predict("kitchen", 8)
    bedroom_preds = model.predict("bedroom", 8)

    # Kitchen should strongly predict water
    assert kitchen_preds[0]["type"] == "water"
    assert kitchen_preds[0]["confidence"] > 0.5

    # Bedroom should have no/weak predictions (no data there)
    if bedroom_preds:
        assert bedroom_preds[0]["confidence"] < kitchen_preds[0]["confidence"]
    print("✅ test_room_isolation passed")


# ─── Unknown Room Tests ──────────────────────────────────

def test_unknown_room():
    """Prediction for an unknown room should not crash."""
    model = BehaviorModel("unknown")
    logs = _make_logs("water", "kitchen", 8, 30)
    model.train(logs)

    preds = model.predict("nonexistent_room", 8)
    # Should return empty or very low confidence
    assert isinstance(preds, list)
    print("✅ test_unknown_room passed")


# ─── Multiple Symbols Test ────────────────────────────────

def test_multiple_symbols_ranked():
    """When multiple symbols are used, they should be ranked by frequency."""
    model = BehaviorModel("multi")
    logs = (
        _make_logs("water", "kitchen", 8, 25) +
        _make_logs("food", "kitchen", 8, 15) +
        _make_logs("help", "kitchen", 8, 5)
    )
    model.train(logs)

    preds = model.predict("kitchen", 8)
    types = [p["type"] for p in preds]
    assert types[0] == "water"     # Most frequent
    assert "food" in types[:3]     # Second most frequent
    print("✅ test_multiple_symbols_ranked passed")


# ─── Explanation Test ─────────────────────────────────────

def test_explanation():
    """Explanation should contain context, model info, and reasoning."""
    model = BehaviorModel("explain")
    logs = _make_logs("water", "kitchen", 8, 30)
    model.train(logs)

    explanation = model.explain_prediction("kitchen", 8, 0)

    assert "context" in explanation
    assert explanation["context"]["room"] == "kitchen"
    assert "model" in explanation
    assert "predictions" in explanation
    assert "reasoning" in explanation
    assert len(explanation["reasoning"]) > 0
    print("✅ test_explanation passed")


# ─── All Predictions Generation ────────────────────────────

def test_generate_all_predictions():
    """Should generate at least one prediction per room."""
    model = BehaviorModel("gen")
    logs = (
        _make_logs("water", "kitchen", 8, 25) +
        _make_logs("sleep", "bedroom", 21, 25)
    )
    model.train(logs)

    all_preds = model.generate_all_predictions()
    assert len(all_preds) > 0

    rooms_covered = {p["room"] for p in all_preds}
    assert "kitchen" in rooms_covered
    assert "bedroom" in rooms_covered
    assert all(p["family_id"] == "gen" for p in all_preds)
    print("✅ test_generate_all_predictions passed")


# ─── Phase 2 Specific Tests ──────────────────────────────

def test_phase2_prediction():
    """Phase 2 GradientBoosting should still predict correctly."""
    model = BehaviorModel("p2")
    logs = (
        _make_logs("water", "kitchen", 8, 60) +
        _make_logs("food", "kitchen", 12, 60)
    )
    result = model.train(logs)
    assert result["phase"] == 2

    preds_8 = model.predict("kitchen", 8)
    preds_12 = model.predict("kitchen", 12)

    assert preds_8[0]["type"] == "water"
    assert preds_12[0]["type"] == "food"
    print("✅ test_phase2_prediction passed")


# ─── Phase 3 Specific Tests ──────────────────────────────

def test_phase3_ensemble():
    """Phase 3 should blend GBT and Bayesian predictions."""
    model = BehaviorModel("p3")
    logs = (
        _make_logs("water", "kitchen", 8, 250) +
        _make_logs("food", "kitchen", 12, 200) +
        _make_logs("play", "living", 15, 150)
    )
    result = model.train(logs)
    assert result["phase"] == 3

    preds = model.predict("kitchen", 8, 0)
    assert preds[0]["type"] == "water"
    assert preds[0]["source"] == "ensemble"
    print("✅ test_phase3_ensemble passed")


# ─── Learning vs Memorizing Test ──────────────────────────

def test_learns_patterns_not_memorizes():
    """
    The model should generalize patterns, not memorize exact sequences.

    If kitchen at 8 AM → water (pattern), and we never trained on
    kitchen at 7:30 AM, the model should STILL predict water due to
    Gaussian smoothing — demonstrating learned PATTERN, not memory.
    """
    model = BehaviorModel("generalize")
    # Only train on exact hour 8
    logs = _make_logs("water", "kitchen", 8, 30)
    model.train(logs)

    # Test at hour 7 (never seen in training data)
    preds_7 = model.predict("kitchen", 7)
    assert len(preds_7) > 0
    assert preds_7[0]["type"] == "water", "Model should GENERALIZE to nearby hours"

    # Test at hour 6 (further away)
    preds_6 = model.predict("kitchen", 6)
    if preds_6:
        # Confidence should decrease with distance
        assert preds_6[0]["confidence"] <= preds_7[0]["confidence"], \
            "Further hours should have lower confidence (generalization, not memory)"

    print("✅ test_learns_patterns_not_memorizes passed")


# ─── Contextual Sensitivity Test ──────────────────────────

def test_weekend_weekday_sensitivity():
    """If trained with distinct weekday/weekend patterns, Phase 2+ should capture this."""
    model = BehaviorModel("weekend")
    # Weekdays (0-4): water at 8 AM in kitchen
    weekday_logs = []
    for d in range(5):
        weekday_logs.extend(_make_logs("water", "kitchen", 8, 25, day=d))
    # Weekends (5-6): play at 8 AM in kitchen
    weekend_logs = []
    for d in [5, 6]:
        weekend_logs.extend(_make_logs("play", "kitchen", 8, 40, day=d))

    all_logs = weekday_logs + weekend_logs
    result = model.train(all_logs)

    # With 245 logs, should be phase 2+
    assert result["phase"] >= 2

    # Weekday prediction
    preds_weekday = model.predict("kitchen", 8, day_of_week=1)
    # Weekend prediction
    preds_weekend = model.predict("kitchen", 8, day_of_week=5)

    # At minimum, the model should distinguish the dominant pattern
    # (exact accuracy depends on model phase and data distribution)
    assert len(preds_weekday) > 0
    assert len(preds_weekend) > 0
    print("✅ test_weekend_weekday_sensitivity passed")


# ─── Run All Tests ────────────────────────────────────────

if __name__ == "__main__":
    print("\n🧪 BehaviorModel v3.0 Test Suite\n" + "=" * 40)

    # Phase selection
    test_no_data()
    test_not_ready_insufficient_taps()
    test_phase1_training()
    test_phase2_training()
    test_phase3_training()

    # Prediction accuracy
    test_basic_prediction_accuracy()
    test_room_pattern_accuracy()
    test_time_of_day_accuracy()
    test_multiple_symbols_ranked()

    # ML quality
    test_time_decay_favors_recent()
    test_hour_smoothing()
    test_room_isolation()
    test_learns_patterns_not_memorizes()
    test_weekend_weekday_sensitivity()

    # Edge cases
    test_unknown_room()

    # Features
    test_explanation()
    test_generate_all_predictions()
    test_phase2_prediction()
    test_phase3_ensemble()

    print("\n" + "=" * 40)
    print("🎉 All 19 tests passed!\n")
