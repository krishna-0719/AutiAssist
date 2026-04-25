# ──────────────────────────────────────────────
# Care & Child AAC — Flutter Development Launcher
# ──────────────────────────────────────────────
# Auto-detects local WiFi IP, reads .env.local,
# and injects all --dart-define flags.
# Usage: .\run_dev.ps1
# ──────────────────────────────────────────────

Write-Host "`n🌈 Care & Child AAC — Development Launcher`n" -ForegroundColor Cyan

# 1. Read .env.local
if (-not (Test-Path ".env.local")) {
    Write-Host "❌ .env.local not found! Create it from the template:" -ForegroundColor Red
    Write-Host "   SUPABASE_URL=https://your-project.supabase.co"
    Write-Host "   SUPABASE_ANON_KEY=your-anon-key"
    exit 1
}

$envVars = @{}
Get-Content ".env.local" | ForEach-Object {
    if ($_ -match "^([^=]+)=(.+)$") {
        $envVars[$matches[1].Trim()] = $matches[2].Trim()
    }
}

$supabaseUrl = $envVars["SUPABASE_URL"]
$supabaseKey = $envVars["SUPABASE_ANON_KEY"]
$behaviorApiKey = $envVars["BEHAVIOR_API_KEY"]

if (-not $supabaseUrl -or -not $supabaseKey) {
    Write-Host "❌ SUPABASE_URL or SUPABASE_ANON_KEY is empty in .env.local" -ForegroundColor Red
    exit 1
}

# 2. Detect local IP for backend
$ip = "10.0.2.2" # Default: Android emulator localhost
try {
    $wifiIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi" -ErrorAction Stop).IPAddress
    if ($wifiIp) { $ip = $wifiIp }
} catch {
    Write-Host "⚠️  Could not detect WiFi IP, using Android emulator default ($ip)" -ForegroundColor Yellow
}

$behaviorUrl = "http://${ip}:7860"

Write-Host "📡 Supabase URL: $supabaseUrl" -ForegroundColor Green
Write-Host "🔑 Anon Key: $($supabaseKey.Substring(0,20))..." -ForegroundColor Green
Write-Host "🧠 Backend URL: $behaviorUrl" -ForegroundColor Green
if ($behaviorApiKey) {
    Write-Host "🔐 Backend API key: configured" -ForegroundColor Green
}
Write-Host ""

# 3. Run Flutter
flutter run `
    --dart-define=SUPABASE_URL=$supabaseUrl `
    --dart-define=SUPABASE_ANON_KEY=$supabaseKey `
    --dart-define=BEHAVIOR_API_URL=$behaviorUrl `
    $(if ($behaviorApiKey) { "--dart-define=BEHAVIOR_API_KEY=$behaviorApiKey" })
