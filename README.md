# 🌈 Care & Child AAC

> AI-powered Augmentative and Alternative Communication for autism support.

```
┌─────────────────────────────────────────────┐
│         Flutter App (Cross-platform)        │
│  ┌──────────────┐    ┌──────────────────┐   │
│  │ Child Device  │←──→│ Caregiver Device │   │
│  │ AAC Board     │ WS │ Dashboard, Mgmt  │   │
│  │ TTS, WiFi KNN │    │ Analytics, Diary │   │
│  └──────┬───────┘    └──────┬───────────┘   │
└─────────┼───────────────────┼───────────────┘
          │                   │
          ▼                   ▼
┌─────────────────────────────────────────────┐
│         Supabase (Backend-as-a-Service)     │
│  Auth │ PostgreSQL (8 tables) │ Realtime    │
│  RLS  │ 5 RPC functions      │ Broadcast   │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│        Python FastAPI ML Backend            │
│  Bayesian → RandomForest │ Per-family models│
│  /log /predict /train /status /health       │
└─────────────────────────────────────────────┘
```

---

## Prerequisites

- **Flutter 3+** (Dart SDK >=3.0.0)
- **Python 3.11+**
- **Supabase account** (free tier works)
- **Android Studio** with emulator (API 26+)

---

## 🚀 Quick Start

### 1. Supabase Setup

1. Create a new Supabase project
2. Open the SQL Editor
3. Paste and run the entire `supabase_schema.sql` file
4. Ensure RLS is enabled on all tables (the schema does this)
5. Insert the ML backend URL into `system_config`:
   ```sql
   UPDATE system_config SET value = 'https://your-backend.com' WHERE key = 'behavior_api_url';
   ```

### 2. Flutter Setup

```bash
# Install dependencies
flutter pub get

# Create your .env.local file
cp .env.local.example .env.local
# Edit .env.local with your Supabase URL and Anon Key:
#   SUPABASE_URL=https://yourproject.supabase.co
#   SUPABASE_ANON_KEY=eyJ...

# Run the app (auto-injects env vars)
.\run_dev.ps1
```

### 3. Backend Setup

```bash
cd backend

# Install Python dependencies
pip install -r requirements.txt

# Create your .env file
cp .env.example .env
# Edit backend/.env with your Supabase URL and SERVICE_ROLE key

# Start the server
.\run_server.ps1
# Or manually:
uvicorn main:app --reload --host 0.0.0.0 --port 7860
```

### 4. Docker Deployment

```bash
cd backend
docker build -t aac-backend .
docker run -p 7860:7860 --env-file .env aac-backend
```

---

## 📋 Environment Variables

| Variable | File | Description |
|---|---|---|
| `SUPABASE_URL` | `.env.local` | Supabase project URL |
| `SUPABASE_ANON_KEY` | `.env.local` | Supabase anonymous API key |
| `BEHAVIOR_API_URL` | auto-detected | ML backend URL (via `run_dev.ps1`) |
| `SUPABASE_URL` | `backend/.env` | Same URL for Python backend |
| `SUPABASE_SERVICE_ROLE_KEY` | `backend/.env` | Server-side key (⚠️ never expose) |

---

## 📡 WiFi Room Detection

The app uses **WiFi fingerprinting** (not GPS) for indoor room detection:

1. **Calibration**: Caregiver stands in each room and scans WiFi (up to 10 data points per room)
2. **Detection**: Child device scans WiFi every 8 seconds
3. **Matching**: Custom KNN algorithm with weighted Euclidean distance
4. **Signal weighting**: Stronger signals get exponentially more weight
5. **Missing signal penalties**: Strong missing signals get heavy penalties (2.5x)
6. **Ambiguity handling**: If 2nd-best room is within 12%, confidence gets a 0.85x penalty
7. **Rolling average**: 3 scans × 800ms, averaged to reduce noise

---

## 🧠 ML Model Progression

| Phase | Condition | Algorithm | Details |
|---|---|---|---|
| **Not Ready** | < 20 taps or < 2 days | None | Shows "training..." status |
| **Phase 1** | 20-199 taps | Bayesian frequency | Hour-smoothed (±1h at 0.3x weight) |
| **Phase 2** | ≥ 200 taps | RandomForest | 50 trees, max_depth=8, 7-day averaging |

---

## 🔧 Troubleshooting

| Problem | Solution |
|---|---|
| `SUPABASE_URL is missing` | Run with `.\run_dev.ps1` or pass `--dart-define=SUPABASE_URL=...` |
| WiFi scan always returns empty | Enable location permissions; on emulator, mock data is used |
| Backend `/predict` returns empty | Need at least 20 taps + 2 days of data before model trains |
| Family code not found | Ensure the code was created on caregiver device first |
| Requests not appearing | Check that both devices use the same family code |
| Charts show no data | RPC functions must be deployed (run `supabase_schema.sql`) |

---

## 📁 Project Structure

```
care_child_v2/
├── lib/
│   ├── main.dart                    # Entry point
│   ├── router.dart                  # GoRouter (16 routes)
│   ├── models/                      # 6 data models
│   ├── providers/                   # 8 Riverpod providers
│   ├── screens/                     # 15 screens
│   ├── services/                    # 6 repositories + 5 services
│   ├── theme/                       # Material 3 theme
│   ├── utils/                       # Logger + exceptions
│   └── widgets/                     # 5 shared widgets
├── backend/
│   ├── main.py                      # FastAPI (5 endpoints)
│   ├── model.py                     # ML model (Bayesian + RF)
│   ├── supabase_client.py           # Python Supabase client
│   ├── test_model.py                # ML tests
│   ├── test_main.py                 # API tests
│   ├── requirements.txt
│   └── Dockerfile
├── supabase_schema.sql              # Full DB schema v4.1
├── pubspec.yaml
├── run_dev.ps1
├── run_server.ps1
└── analysis_options.yaml
```

---

## 📄 License

This project is built for educational and therapeutic purposes.
