"""
BehaviorModel v3.0 — Per-family contextual behavior predictor.

PHILOSOPHY:
  The model learns BEHAVIORAL PATTERNS, not memorized sequences.
  It answers: "Given this room + time-of-day + day-of-week, what does
  THIS child typically need?"  Not "what did they tap last time?"

  Example learned patterns:
    - "In the kitchen at 8 AM on weekdays → water (72%), food (18%)"
    - "In the bedroom at 9 PM → sleep (65%), hug (22%)"
    - "In the living room on weekends at 3 PM → play (58%), music (28%)"

THREE-PHASE LEARNING:
  Phase 1 (20-99 taps):   Bayesian frequency with Gaussian hour smoothing + time decay
  Phase 2 (100-499 taps): GradientBoosting with rich contextual features  
  Phase 3 (500+ taps):    Ensemble of GradientBoosting + time-weighted Bayesian

KEY TECHNIQUES:
  - Time-decay weighting: Recent taps matter 2x more than month-old taps
  - Gaussian hour smoothing: 8 AM context bleeds into 7 AM and 9 AM naturally
  - Cyclical feature encoding: Hour and day-of-week as sin/cos pairs
  - Contextual features: is_morning, is_afternoon, is_evening, is_weekend
  - Laplace smoothing: Prevents zero-probability predictions
  - Confidence calibration: Returns honest confidence scores
"""

import math
from datetime import datetime, timezone
from collections import defaultdict
from typing import Optional

import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import cross_val_score
from sklearn.calibration import CalibratedClassifierCV

# ─── Configuration ────────────────────────────────────────
MIN_TAPS = 20
MIN_TRAINING_DAYS = 2
PHASE2_THRESHOLD = 100
PHASE3_THRESHOLD = 500
CONFIDENCE_FLOOR = 0.04        # Filter below 4%
TIME_DECAY_HALF_LIFE_DAYS = 14  # Recent behavior matters more
GAUSSIAN_SIGMA_HOURS = 1.5     # Hour smoothing width
LAPLACE_ALPHA = 0.5            # Smoothing for frequency model
TOP_K_PREDICTIONS = 5          # Return top 5 predictions


def _time_decay_weight(days_ago: float, half_life: float = TIME_DECAY_HALF_LIFE_DAYS) -> float:
    """Exponential decay: weight = 0.5^(days_ago / half_life)."""
    return math.pow(0.5, days_ago / half_life)


def _gaussian_weight(hour_diff: float, sigma: float = GAUSSIAN_SIGMA_HOURS) -> float:
    """Gaussian kernel for hour smoothing."""
    return math.exp(-(hour_diff ** 2) / (2 * sigma ** 2))


def _hour_distance(h1: int, h2: int) -> float:
    """Circular distance between two hours (0-23)."""
    diff = abs(h1 - h2)
    return min(diff, 24 - diff)


def _extract_time_features(hour: int, day_of_week: int) -> dict:
    """Extract rich contextual features from time."""
    hour_rad = 2 * math.pi * hour / 24
    day_rad = 2 * math.pi * day_of_week / 7

    return {
        "hour": hour,
        "hour_sin": math.sin(hour_rad),
        "hour_cos": math.cos(hour_rad),
        "day_of_week": day_of_week,
        "day_sin": math.sin(day_rad),
        "day_cos": math.cos(day_rad),
        "is_morning": 1 if 6 <= hour < 12 else 0,      # 6 AM - 12 PM
        "is_afternoon": 1 if 12 <= hour < 17 else 0,    # 12 PM - 5 PM
        "is_evening": 1 if 17 <= hour < 21 else 0,      # 5 PM - 9 PM
        "is_night": 1 if hour >= 21 or hour < 6 else 0, # 9 PM - 6 AM
        "is_weekend": 1 if day_of_week >= 5 else 0,     # Sat/Sun
    }


class BehaviorModel:
    """Per-family behavior prediction model with 3-phase learning."""

    def __init__(self, family_id: str):
        self.family_id = family_id
        self.gb_model: Optional[GradientBoostingClassifier] = None
        self.calibrated_model = None
        self.room_encoder = LabelEncoder()
        self.type_encoder = LabelEncoder()
        self.freq_table: dict[str, dict[str, dict[str, float]]] = {}
        self.trained = False
        self.model_version = "untrained"
        self.unique_rooms: list[str] = []
        self.unique_types: list[str] = []
        self.training_meta: dict = {}
        self._room_classes: list[str] = []
        self._type_classes: list[str] = []

    # ─── Training Entry Point ──────────────────────────────

    def train(self, logs: list[dict]) -> dict:
        """
        Train the model on behavior logs.
        Automatically selects the right phase based on data volume.
        """
        if not logs:
            return {"status": "no_data", "total_taps": 0}

        total_taps = len(logs)

        # Check readiness
        earliest = self._get_earliest_timestamp(logs)
        days_elapsed = 0
        if earliest:
            days_elapsed = (datetime.now(timezone.utc) - earliest).days

        if total_taps < MIN_TAPS or days_elapsed < MIN_TRAINING_DAYS:
            return {
                "status": "not_ready",
                "total_taps": total_taps,
                "days_elapsed": days_elapsed,
                "min_taps": MIN_TAPS,
                "min_days": MIN_TRAINING_DAYS,
            }

        # Extract unique values
        self.unique_rooms = sorted(set(
            log.get("room", "unknown") or "unknown" for log in logs
        ))
        self.unique_types = sorted(set(
            log.get("symbol_type", "") for log in logs if log.get("symbol_type")
        ))

        if not self.unique_types:
            return {"status": "no_data", "total_taps": total_taps}

        # Always build frequency table (used by all phases)
        self._build_frequency_table(logs)

        # Select phase
        if total_taps >= PHASE3_THRESHOLD:
            return self._train_phase3(logs, total_taps, days_elapsed)
        elif total_taps >= PHASE2_THRESHOLD:
            return self._train_phase2(logs, total_taps, days_elapsed)
        else:
            return self._train_phase1(logs, total_taps, days_elapsed)

    # ─── Phase 1: Bayesian Frequency ──────────────────────

    def _build_frequency_table(self, logs: list[dict]) -> None:
        """
        Build time-decayed, hour-smoothed frequency table.

        Structure: freq_table[room][hour_bucket][symbol_type] = weighted_count

        Key innovations:
        1. Time decay: Recent taps get higher weight
        2. Gaussian hour smoothing: Each tap spreads influence to nearby hours
        3. Laplace smoothing: Prevents zero probabilities
        """
        self.freq_table = {}
        now = datetime.now(timezone.utc)

        for log in logs:
            room = log.get("room", "unknown") or "unknown"
            hour = int(log.get("hour_of_day", 12))
            symbol = log.get("symbol_type", "")
            if not symbol:
                continue

            # Calculate time decay weight
            created = self._parse_timestamp(log.get("created_at", ""))
            if created:
                days_ago = max(0, (now - created).total_seconds() / 86400)
            else:
                days_ago = 30  # Default: assume month-old

            decay_weight = _time_decay_weight(days_ago)

            # Apply Gaussian hour smoothing
            for h in range(24):
                h_dist = _hour_distance(h, hour)
                if h_dist > 4:  # Cut off at 4 hours to save computation
                    continue

                gauss_weight = _gaussian_weight(h_dist)
                combined_weight = decay_weight * gauss_weight

                if combined_weight < 0.01:  # Skip negligible contributions
                    continue

                if room not in self.freq_table:
                    self.freq_table[room] = {}
                hour_key = str(h)
                if hour_key not in self.freq_table[room]:
                    self.freq_table[room][hour_key] = {}

                self.freq_table[room][hour_key][symbol] = (
                    self.freq_table[room][hour_key].get(symbol, 0) + combined_weight
                )

        # Add Laplace smoothing
        for room in self.freq_table:
            for hour_key in self.freq_table[room]:
                for symbol_type in self.unique_types:
                    if symbol_type not in self.freq_table[room][hour_key]:
                        self.freq_table[room][hour_key][symbol_type] = LAPLACE_ALPHA

    def _train_phase1(self, logs: list[dict], total_taps: int, days: int) -> dict:
        """Phase 1: Bayesian frequency model only."""
        self.trained = True
        self.model_version = "bayesian_v3"
        self.training_meta = {
            "phase": 1,
            "total_taps": total_taps,
            "days_elapsed": days,
            "rooms": len(self.unique_rooms),
            "symbol_types": len(self.unique_types),
        }
        return {
            "status": "trained",
            "model": "bayesian_frequency",
            "phase": 1,
            **self.training_meta,
        }

    # ─── Phase 2: GradientBoosting ────────────────────────

    def _train_phase2(self, logs: list[dict], total_taps: int, days: int) -> dict:
        """
        Phase 2: GradientBoosting with rich feature engineering.

        Features per tap:
         - room (one-hot encoded)
         - hour_sin, hour_cos (cyclical)
         - day_sin, day_cos (cyclical)
         - is_morning, is_afternoon, is_evening, is_night
         - is_weekend
         - room-hour interaction features
        """
        df = pd.DataFrame(logs)
        df = df.dropna(subset=["symbol_type"])
        df["room"] = df["room"].fillna("unknown")
        df["hour_of_day"] = df["hour_of_day"].fillna(12).astype(int)
        df["day_of_week"] = df["day_of_week"].fillna(0).astype(int)

        if len(df) < MIN_TAPS:
            return self._train_phase1(logs, total_taps, days)

        # Fit encoders
        self._room_classes = sorted(df["room"].unique().tolist())
        self._type_classes = sorted(df["symbol_type"].unique().tolist())
        self.room_encoder.fit(self._room_classes)
        self.type_encoder.fit(self._type_classes)

        # Build feature matrix
        features = self._build_feature_matrix(df)
        target = self.type_encoder.transform(df["symbol_type"])

        # Need at least 2 classes
        if len(set(target)) < 2:
            return self._train_phase1(logs, total_taps, days)

        # Train GradientBoosting (better than RF for tabular data)
        self.gb_model = GradientBoostingClassifier(
            n_estimators=80,
            max_depth=5,
            learning_rate=0.1,
            min_samples_split=5,
            min_samples_leaf=3,
            subsample=0.8,
            random_state=42,
        )
        self.gb_model.fit(features, target)

        # Cross-validation score
        cv_score = 0.0
        if len(df) >= 30 and len(set(target)) >= 2:
            try:
                cv_scores = cross_val_score(
                    self.gb_model, features, target,
                    cv=min(5, len(df) // 10), scoring="accuracy"
                )
                cv_score = float(cv_scores.mean())
            except Exception:
                cv_score = 0.0

        self.trained = True
        self.model_version = "gradient_boost_v3"
        self.training_meta = {
            "phase": 2,
            "total_taps": total_taps,
            "days_elapsed": days,
            "rooms": len(self.unique_rooms),
            "symbol_types": len(self.unique_types),
            "cv_accuracy": round(cv_score, 3),
            "n_features": features.shape[1],
        }
        return {
            "status": "trained",
            "model": "gradient_boosting",
            "phase": 2,
            **self.training_meta,
        }

    # ─── Phase 3: Ensemble ────────────────────────────────

    def _train_phase3(self, logs: list[dict], total_taps: int, days: int) -> dict:
        """
        Phase 3: Ensemble — GradientBoosting + calibrated Bayesian.

        With 500+ taps we have enough data for:
        1. A stronger GradientBoosting model with more trees
        2. Probability calibration via CalibratedClassifierCV
        3. Ensemble: 60% GBT + 40% Bayesian (hedges against overfitting)
        """
        df = pd.DataFrame(logs)
        df = df.dropna(subset=["symbol_type"])
        df["room"] = df["room"].fillna("unknown")
        df["hour_of_day"] = df["hour_of_day"].fillna(12).astype(int)
        df["day_of_week"] = df["day_of_week"].fillna(0).astype(int)

        if len(df) < PHASE2_THRESHOLD:
            return self._train_phase2(logs, total_taps, days)

        # Fit encoders
        self._room_classes = sorted(df["room"].unique().tolist())
        self._type_classes = sorted(df["symbol_type"].unique().tolist())
        self.room_encoder.fit(self._room_classes)
        self.type_encoder.fit(self._type_classes)

        features = self._build_feature_matrix(df)
        target = self.type_encoder.transform(df["symbol_type"])

        if len(set(target)) < 2:
            return self._train_phase1(logs, total_taps, days)

        # Stronger GBT with more trees
        base_model = GradientBoostingClassifier(
            n_estimators=120,
            max_depth=6,
            learning_rate=0.08,
            min_samples_split=4,
            min_samples_leaf=2,
            subsample=0.85,
            random_state=42,
        )
        base_model.fit(features, target)
        self.gb_model = base_model

        # Calibrate probabilities (Platt scaling)
        try:
            self.calibrated_model = CalibratedClassifierCV(
                base_model, cv=min(5, len(df) // 20), method="sigmoid"
            )
            self.calibrated_model.fit(features, target)
        except Exception:
            self.calibrated_model = None

        # Cross-validation
        cv_score = 0.0
        try:
            cv_scores = cross_val_score(
                base_model, features, target,
                cv=min(5, len(df) // 20), scoring="accuracy"
            )
            cv_score = float(cv_scores.mean())
        except Exception:
            pass

        self.trained = True
        self.model_version = "ensemble_v3"
        self.training_meta = {
            "phase": 3,
            "total_taps": total_taps,
            "days_elapsed": days,
            "rooms": len(self.unique_rooms),
            "symbol_types": len(self.unique_types),
            "cv_accuracy": round(cv_score, 3),
            "n_features": features.shape[1],
            "calibrated": self.calibrated_model is not None,
        }
        return {
            "status": "trained",
            "model": "ensemble",
            "phase": 3,
            **self.training_meta,
        }

    # ─── Feature Engineering ──────────────────────────────

    def _build_feature_matrix(self, df: pd.DataFrame) -> pd.DataFrame:
        """Build rich feature matrix from log dataframe."""
        room_encoded = self.room_encoder.transform(df["room"])
        hours = df["hour_of_day"].astype(int)
        days = df["day_of_week"].astype(int)

        features = pd.DataFrame({
            "room_enc": room_encoded,
            # Cyclical time encoding
            "hour_sin": np.sin(2 * np.pi * hours / 24),
            "hour_cos": np.cos(2 * np.pi * hours / 24),
            "day_sin": np.sin(2 * np.pi * days / 7),
            "day_cos": np.cos(2 * np.pi * days / 7),
            # Time-of-day buckets
            "is_morning": ((hours >= 6) & (hours < 12)).astype(int),
            "is_afternoon": ((hours >= 12) & (hours < 17)).astype(int),
            "is_evening": ((hours >= 17) & (hours < 21)).astype(int),
            "is_night": ((hours >= 21) | (hours < 6)).astype(int),
            # Weekend flag
            "is_weekend": (days >= 5).astype(int),
            # Room-time interaction (captures "kitchen in morning" patterns)
            "room_hour_interaction": room_encoded * hours / 24.0,
            "room_day_interaction": room_encoded * days / 7.0,
        })

        # One-hot encode rooms (captures room-specific patterns better)
        for i, room_name in enumerate(self._room_classes):
            features[f"room_{i}"] = (room_encoded == i).astype(int)

        return features

    def _build_single_features(self, room: str, hour: int, day_of_week: int) -> pd.DataFrame:
        """Build feature row for a single prediction context."""
        if room in self._room_classes:
            room_enc = self.room_encoder.transform([room])[0]
        else:
            room_enc = 0  # Default to first room for unknown

        features = {
            "room_enc": room_enc,
            "hour_sin": math.sin(2 * math.pi * hour / 24),
            "hour_cos": math.cos(2 * math.pi * hour / 24),
            "day_sin": math.sin(2 * math.pi * day_of_week / 7),
            "day_cos": math.cos(2 * math.pi * day_of_week / 7),
            "is_morning": 1 if 6 <= hour < 12 else 0,
            "is_afternoon": 1 if 12 <= hour < 17 else 0,
            "is_evening": 1 if 17 <= hour < 21 else 0,
            "is_night": 1 if hour >= 21 or hour < 6 else 0,
            "is_weekend": 1 if day_of_week >= 5 else 0,
            "room_hour_interaction": room_enc * hour / 24.0,
            "room_day_interaction": room_enc * day_of_week / 7.0,
        }

        for i, _ in enumerate(self._room_classes):
            features[f"room_{i}"] = 1 if room_enc == i else 0

        return pd.DataFrame([features])

    # ─── Prediction ────────────────────────────────────────

    def predict(self, room: str, hour: Optional[int] = None,
                day_of_week: Optional[int] = None) -> list[dict]:
        """
        Predict top symbols for a given context.

        The prediction represents learned behavioral PATTERNS:
        "Children in this family typically want X in this room at this time."

        Phase 1: Pure Bayesian frequency
        Phase 2: GradientBoosting only
        Phase 3: Ensemble (60% GBT + 40% Bayesian)
        """
        if not self.trained:
            return []

        if hour is None:
            hour = datetime.now().hour
        if day_of_week is None:
            day_of_week = datetime.now().weekday()

        # Get Bayesian predictions (always available)
        bayesian_preds = self._predict_bayesian(room, hour)

        # Phase 1: Bayesian only
        if self.gb_model is None:
            return bayesian_preds[:TOP_K_PREDICTIONS]

        # Phase 2/3: GBT predictions
        gbt_preds = self._predict_gbt(room, hour, day_of_week)

        if not gbt_preds:
            return bayesian_preds[:TOP_K_PREDICTIONS]

        # Phase 2: GBT only
        if self.model_version == "gradient_boost_v3":
            return gbt_preds[:TOP_K_PREDICTIONS]

        # Phase 3: Ensemble blending
        return self._blend_predictions(
            gbt_preds, bayesian_preds,
            gbt_weight=0.6, bayesian_weight=0.4,
        )[:TOP_K_PREDICTIONS]

    def _predict_bayesian(self, room: str, hour: int) -> list[dict]:
        """Bayesian frequency-based prediction with Laplace smoothing."""
        room_data = self.freq_table.get(room, {})
        hour_data = room_data.get(str(hour), {})

        if not hour_data:
            # Fall back to global room data (aggregate all hours)
            hour_data = {}
            for h_data in room_data.values():
                for symbol, count in h_data.items():
                    hour_data[symbol] = hour_data.get(symbol, 0) + count

        if not hour_data:
            return []

        total = sum(hour_data.values())
        predictions = []
        for symbol, count in hour_data.items():
            confidence = count / total
            if confidence >= CONFIDENCE_FLOOR:
                predictions.append({
                    "type": symbol,
                    "confidence": round(confidence, 4),
                    "source": "bayesian",
                })

        predictions.sort(key=lambda x: x["confidence"], reverse=True)
        return predictions

    def _predict_gbt(self, room: str, hour: int, day_of_week: int) -> list[dict]:
        """GradientBoosting prediction averaged across all 7 days (for Phase 2)
        or specific day (for Phase 3)."""
        try:
            model = self.calibrated_model or self.gb_model

            if self.model_version == "ensemble_v3":
                # Phase 3: Use specific day for precision
                features = self._build_single_features(room, hour, day_of_week)
                probas = model.predict_proba(features)[0]
            else:
                # Phase 2: Average across all 7 days for robustness
                probas_sum = None
                for day in range(7):
                    features = self._build_single_features(room, hour, day)
                    p = model.predict_proba(features)[0]
                    if probas_sum is None:
                        probas_sum = p.copy()
                    else:
                        probas_sum += p
                probas = probas_sum / 7.0

            classes = self.type_encoder.inverse_transform(range(len(probas)))

            predictions = []
            for cls, prob in zip(classes, probas):
                if prob >= CONFIDENCE_FLOOR:
                    predictions.append({
                        "type": str(cls),
                        "confidence": round(float(prob), 4),
                        "source": "gradient_boosting",
                    })

            predictions.sort(key=lambda x: x["confidence"], reverse=True)
            return predictions

        except Exception:
            return []

    def _blend_predictions(self, gbt_preds: list[dict], bayes_preds: list[dict],
                           gbt_weight: float, bayesian_weight: float) -> list[dict]:
        """Blend GBT and Bayesian predictions with weighted ensemble."""
        combined: dict[str, float] = {}

        for pred in gbt_preds:
            combined[pred["type"]] = combined.get(pred["type"], 0) + pred["confidence"] * gbt_weight

        for pred in bayes_preds:
            combined[pred["type"]] = combined.get(pred["type"], 0) + pred["confidence"] * bayesian_weight

        # Renormalize
        total = sum(combined.values())
        if total == 0:
            return []

        predictions = []
        for symbol_type, score in combined.items():
            confidence = score / total
            if confidence >= CONFIDENCE_FLOOR:
                predictions.append({
                    "type": symbol_type,
                    "confidence": round(confidence, 4),
                    "source": "ensemble",
                })

        predictions.sort(key=lambda x: x["confidence"], reverse=True)
        return predictions

    # ─── Bulk Predictions ──────────────────────────────────

    def generate_all_predictions(self) -> list[dict]:
        """Generate predictions for all (room, hour, day) combinations."""
        all_predictions = []
        for room in self.unique_rooms:
            for hour in range(24):
                # Average across all days for storage
                preds = self.predict(room, hour, day_of_week=None)
                if preds:
                    all_predictions.append({
                        "family_id": self.family_id,
                        "room": room,
                        "hour_bucket": hour,
                        "predicted_types": preds[:3],
                        "confidence": preds[0]["confidence"] if preds else 0,
                        "model_version": self.model_version,
                    })
        return all_predictions

    # ─── Explanation ──────────────────────────────────────

    def explain_prediction(self, room: str, hour: int,
                           day_of_week: Optional[int] = None) -> dict:
        """Explain why the model predicted what it did."""
        if day_of_week is None:
            day_of_week = datetime.now().weekday()

        predictions = self.predict(room, hour, day_of_week)

        time_features = _extract_time_features(hour, day_of_week)
        time_period = "morning" if time_features["is_morning"] else \
                      "afternoon" if time_features["is_afternoon"] else \
                      "evening" if time_features["is_evening"] else "night"

        explanation = {
            "context": {
                "room": room,
                "hour": hour,
                "day_of_week": day_of_week,
                "time_period": time_period,
                "is_weekend": bool(time_features["is_weekend"]),
            },
            "model": {
                "version": self.model_version,
                "phase": self.training_meta.get("phase", 0),
                "total_taps_trained": self.training_meta.get("total_taps", 0),
                "cv_accuracy": self.training_meta.get("cv_accuracy"),
            },
            "predictions": predictions,
            "reasoning": [],
        }

        # Add human-readable reasoning
        if predictions:
            top = predictions[0]
            explanation["reasoning"].append(
                f"In the {room} during {time_period}, the child most often needs "
                f"'{top['type']}' ({int(top['confidence'] * 100)}% of the time)."
            )

            # Check room-specific frequency
            room_data = self.freq_table.get(room, {})
            hour_data = room_data.get(str(hour), {})
            if hour_data:
                total_in_context = sum(hour_data.values())
                explanation["reasoning"].append(
                    f"Based on {int(total_in_context)} weighted observations "
                    f"in this context (time-decayed)."
                )

        return explanation

    # ─── Utilities ────────────────────────────────────────

    @staticmethod
    def _get_earliest_timestamp(logs: list[dict]) -> Optional[datetime]:
        """Get earliest created_at from logs."""
        timestamps = []
        for log in logs:
            ts = BehaviorModel._parse_timestamp(log.get("created_at", ""))
            if ts:
                timestamps.append(ts)
        return min(timestamps) if timestamps else None

    @staticmethod
    def _parse_timestamp(ts_str: str) -> Optional[datetime]:
        """Parse an ISO timestamp string."""
        if not ts_str:
            return None
        try:
            return datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        except (ValueError, TypeError):
            return None
