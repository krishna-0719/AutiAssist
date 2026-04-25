# ──────────────────────────────────────────────
# Care & Child AAC — Backend Server Launcher
# ──────────────────────────────────────────────
# Usage: .\run_server.ps1
# ──────────────────────────────────────────────

Write-Host "`n🧠 Care & Child AAC — ML Backend`n" -ForegroundColor Cyan

Set-Location backend

if (-not (Test-Path ".env")) {
    Write-Host "⚠️  backend/.env not found! Copy from .env.example" -ForegroundColor Yellow
}

Write-Host "Starting FastAPI server on port 7860..." -ForegroundColor Green
uvicorn main:app --reload --host 0.0.0.0 --port 7860
