"""
Care & Child AAC — FastAPI ML Backend v3.0 (Security-Hardened + Enhanced ML)

Endpoints:
  POST /log                        — Record symbol tap event
  GET  /predict/{family_id}/{room} — Get predictions for context
  POST /train/{family_id}          — Train/retrain model
  GET  /status/{family_id}         — Training readiness status
  GET  /explain/{family_id}/{room} — Explain prediction reasoning
  GET  /health                     — Health check with uptime

Security: API key auth, rate limiting, input sanitization, security headers.
"""

import os
import time
import secrets
from datetime import datetime, timezone
from collections import defaultdict

from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, field_validator

import supabase_client as db
from model import BehaviorModel, MIN_TAPS, MIN_TRAINING_DAYS

from dotenv import load_dotenv
load_dotenv()

API_KEY = os.getenv("API_KEY", "")
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*").split(",")
RATE_LIMIT_WINDOW = 60
RATE_LIMIT_MAX = 120
MAX_BODY_SIZE = 1_000_000

app = FastAPI(
    title="Care & Child AAC — ML Backend",
    version="3.0.0",
    description="Per-family contextual behavior prediction API.",
    docs_url="/docs" if not API_KEY else None,
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# ─── Rate Limiting (with cleanup) ─────────────────────────
_rate_limit_store: dict[str, list[float]] = defaultdict(list)
_rate_limit_last_cleanup: float = time.time()
RATE_LIMIT_CLEANUP_INTERVAL = 300  # Cleanup stale IPs every 5 minutes

def _check_rate_limit(ip: str) -> bool:
    global _rate_limit_last_cleanup
    now = time.time()
    window_start = now - RATE_LIMIT_WINDOW
    _rate_limit_store[ip] = [t for t in _rate_limit_store[ip] if t > window_start]
    if len(_rate_limit_store[ip]) >= RATE_LIMIT_MAX:
        return False
    _rate_limit_store[ip].append(now)

    # Periodic cleanup: remove IPs with no recent activity
    if now - _rate_limit_last_cleanup > RATE_LIMIT_CLEANUP_INTERVAL:
        _rate_limit_last_cleanup = now
        stale_ips = [ip_key for ip_key, timestamps in _rate_limit_store.items()
                     if not timestamps or timestamps[-1] < window_start]
        for stale_ip in stale_ips:
            del _rate_limit_store[stale_ip]
    return True

# ─── Security Middleware ──────────────────────────────────
@app.middleware("http")
async def security_middleware(request: Request, call_next):
    client_ip = request.client.host if request.client else "unknown"
    if not _check_rate_limit(client_ip):
        return JSONResponse(status_code=429, content={"detail": "Rate limit exceeded."})

    content_length = request.headers.get("content-length")
    if content_length and int(content_length) > MAX_BODY_SIZE:
        return JSONResponse(status_code=413, content={"detail": "Request body too large."})

    if API_KEY:
        if request.url.path not in ["/", "/health", "/docs", "/openapi.json"]:
            provided_key = request.headers.get("X-API-Key", "")
            if not secrets.compare_digest(provided_key, API_KEY):
                return JSONResponse(status_code=401, content={"detail": "Invalid API key."})

    try:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        return response
    except Exception:
        return JSONResponse(status_code=500, content={"detail": "Internal server error."})

# ─── Model Cache (LRU with max size) ─────────────────────
MODEL_CACHE_MAX_SIZE = 100
_model_cache: dict[str, BehaviorModel] = {}
_model_access_order: list[str] = []  # Track access order for LRU

def _get_model(family_id: str) -> BehaviorModel:
    if family_id in _model_cache:
        # Move to end (most recently used)
        if family_id in _model_access_order:
            _model_access_order.remove(family_id)
        _model_access_order.append(family_id)
        return _model_cache[family_id]

    # Evict oldest if at capacity
    while len(_model_cache) >= MODEL_CACHE_MAX_SIZE and _model_access_order:
        evict_id = _model_access_order.pop(0)
        _model_cache.pop(evict_id, None)

    _model_cache[family_id] = BehaviorModel(family_id)
    _model_access_order.append(family_id)
    return _model_cache[family_id]

def _ensure_model_trained(family_id: str) -> BehaviorModel:
    """Get a model, auto-training from DB if needed."""
    model = _get_model(family_id)
    if not model.trained:
        try:
            client = db.get_client()
            logs = db.fetch_behavior_logs(client, family_id)
            if logs:
                model.train(logs)
        except Exception:
            pass
    return model

# ─── Input Validation ─────────────────────────────────────

def _sanitize_id(value: str) -> str:
    return "".join(c for c in value if c.isalnum() or c in "-_")[:100]

class LogRequest(BaseModel):
    family_id: str = Field(..., min_length=1, max_length=100)
    user_id: str = Field(default="", max_length=100)
    symbol_type: str = Field(..., min_length=1, max_length=50)
    room: str = Field(default="unknown", max_length=50)
    hour_of_day: int = Field(default=12, ge=0, le=23)
    day_of_week: int = Field(default=0, ge=0, le=6)

    @field_validator("family_id", "user_id")
    @classmethod
    def sanitize_ids(cls, v: str) -> str:
        return _sanitize_id(v)

    @field_validator("symbol_type", "room")
    @classmethod
    def sanitize_text(cls, v: str) -> str:
        return v.strip().replace("'", "").replace('"', "").replace(";", "")[:50]

class TrainResponse(BaseModel):
    status: str
    model: str = ""
    phase: int = 0
    total_taps: int = 0
    days_elapsed: int = 0
    rooms: int = 0
    symbol_types: int = 0
    predictions_generated: int = 0
    cv_accuracy: float = 0.0

# ─── Startup ─────────────────────────────────────────────
_start_time = time.time()

# ─── Endpoints ────────────────────────────────────────────

@app.get("/")
async def root():
    """Welcome endpoint for browser checks."""
    return {"status": "online", "message": "Care & Child AAC ML API is running.", "version": app.version}

def _background_train(family_id: str):
    """Background task to run ML training."""
    try:
        client = db.get_client()
        logs = db.fetch_behavior_logs(client, family_id)
        if not logs: return
        
        model = _get_model(family_id)
        result = model.train(logs)
        
        if result["status"] == "trained":
            all_preds = model.generate_all_predictions()
            for pred in all_preds:
                db.upsert_prediction(client, pred)
                
            db.upsert_training_status(client, family_id, {
                "total_taps": result.get("total_taps", 0),
                "is_ready": True,
                "last_trained_at": datetime.now(timezone.utc).isoformat(),
            })
    except Exception as e:
        print(f"Background train error for {family_id}: {e}")

@app.post("/log")
async def log_tap(req: LogRequest, bg_tasks: BackgroundTasks):
    """Record a symbol tap and update training status."""
    try:
        client = db.get_client()

        log_data = {
            "family_id": req.family_id,
            "user_id": req.user_id if req.user_id else None,
            "symbol_type": req.symbol_type,
            "room": req.room,
            "hour_of_day": req.hour_of_day,
            "day_of_week": req.day_of_week,
        }
        db.insert_behavior_log(client, log_data)

        total = db.count_behavior_logs(client, req.family_id)
        earliest = db.get_earliest_log(client, req.family_id)
        days = 0
        if earliest:
            try:
                first = datetime.fromisoformat(earliest["created_at"].replace("Z", "+00:00"))
                days = (datetime.now(timezone.utc) - first).days
            except (ValueError, TypeError):
                pass

        is_ready = total >= MIN_TAPS and days >= MIN_TRAINING_DAYS

        # Auto-retrain if model is stale (every 50 new taps)
        model = _get_model(req.family_id)
        old_taps = model.training_meta.get("total_taps", 0)
        if is_ready and (total - old_taps) >= 50:
            bg_tasks.add_task(_background_train, req.family_id)

        db.upsert_training_status(client, req.family_id, {
            "total_taps": total,
            "is_ready": is_ready,
        })

        return {"status": "logged", "total_taps": total, "is_ready": is_ready}

    except Exception:
        raise HTTPException(status_code=500, detail="Failed to log tap.")


@app.get("/predict/{family_id}/{room}")
async def predict(family_id: str, room: str, hour: int = -1, day: int = -1):
    """
    Get contextual predictions.

    The model answers: "Given this room + time, what does this child
    typically need?" — based on learned behavioral patterns.

    Optional query params:
      - hour: Override current hour (0-23)
      - day: Override current day of week (0=Mon, 6=Sun)
    """
    family_id = _sanitize_id(family_id)
    room = room.strip()[:50]

    model = _ensure_model_trained(family_id)

    current_hour = hour if 0 <= hour <= 23 else datetime.now().hour
    current_day = day if 0 <= day <= 6 else datetime.now().weekday()

    predictions = model.predict(room, current_hour, current_day)

    return {
        "family_id": family_id,
        "room": room,
        "hour": current_hour,
        "day_of_week": current_day,
        "is_ready": model.trained,
        "model_version": model.model_version,
        "phase": model.training_meta.get("phase", 0),
        "predictions": predictions,
    }


@app.post("/train/{family_id}")
async def train_model(family_id: str, bg_tasks: BackgroundTasks):
    """Train or retrain the ML model for a family (Background)."""
    family_id = _sanitize_id(family_id)

    try:
        client = db.get_client()
        logs = db.fetch_behavior_logs(client, family_id)

        if not logs:
            return TrainResponse(status="no_data")

        bg_tasks.add_task(_background_train, family_id)
        return TrainResponse(status="training_started", total_taps=len(logs))

    except Exception:
        raise HTTPException(status_code=500, detail="Training failed.")


@app.get("/explain/{family_id}/{room}")
async def explain_prediction(family_id: str, room: str,
                              hour: int = -1, day: int = -1):
    """
    Explain WHY the model predicted what it did.

    Returns human-readable reasoning about the behavioral patterns
    the model has learned for this context.
    """
    family_id = _sanitize_id(family_id)
    room = room.strip()[:50]

    model = _ensure_model_trained(family_id)

    current_hour = hour if 0 <= hour <= 23 else datetime.now().hour
    current_day = day if 0 <= day <= 6 else datetime.now().weekday()

    if not model.trained:
        return {
            "family_id": family_id,
            "explanation": {"reasoning": ["Model not yet trained. Need more data."]},
        }

    explanation = model.explain_prediction(room, current_hour, current_day)
    return {
        "family_id": family_id,
        "explanation": explanation,
    }


@app.get("/status/{family_id}")
async def training_status(family_id: str):
    """Get training readiness status."""
    family_id = _sanitize_id(family_id)

    try:
        client = db.get_client()
        status = db.get_training_status(client, family_id)

        if status is None:
            total = db.count_behavior_logs(client, family_id)
            earliest = db.get_earliest_log(client, family_id)
            days = 0
            if earliest:
                try:
                    first = datetime.fromisoformat(earliest["created_at"].replace("Z", "+00:00"))
                    days = (datetime.now(timezone.utc) - first).days
                except (ValueError, TypeError):
                    pass

            return {
                "family_id": family_id,
                "total_taps": total,
                "days_elapsed": days,
                "is_ready": total >= MIN_TAPS and days >= MIN_TRAINING_DAYS,
                "last_trained_at": None,
                "min_taps": MIN_TAPS,
                "min_days": MIN_TRAINING_DAYS,
            }

        # Add model info if cached
        model = _model_cache.get(family_id)
        model_info = {}
        if model and model.trained:
            model_info = {
                "model_version": model.model_version,
                "phase": model.training_meta.get("phase", 0),
                "cv_accuracy": model.training_meta.get("cv_accuracy"),
            }

        return {
            "family_id": family_id,
            "total_taps": status.get("total_taps", 0),
            "is_ready": status.get("is_ready", False),
            "last_trained_at": status.get("last_trained_at"),
            "min_taps": MIN_TAPS,
            "min_days": MIN_TRAINING_DAYS,
            **model_info,
        }

    except Exception:
        raise HTTPException(status_code=500, detail="Failed to retrieve status.")


@app.get("/health")
async def health_check():
    """Health check (always public)."""
    return {
        "status": "healthy",
        "version": "3.0.0",
        "cached_models": len(_model_cache),
        "uptime_seconds": round(time.time() - _start_time, 1),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=7860, reload=True)
