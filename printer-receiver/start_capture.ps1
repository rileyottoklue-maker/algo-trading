# start_capture.ps1 — bring up the Phase 0 capture pipeline.
#
# Starts two visible console windows:
#   1. The FastAPI logging receiver on 127.0.0.1:8000
#   2. An ngrok tunnel exposing it to the internet
# Then prints the public webhook URL to paste into TradingView alerts.
#
# Run it from anywhere:  powershell -File start_capture.ps1
# Re-run after any reboot.

$ErrorActionPreference = "Stop"

# Static ngrok domain reserved to this account. Because it never changes,
# the TradingView alert webhook URLs never need re-pasting after a restart —
# a stale URL would mean silently lost captures.
$staticDomain = "gleaming-public-reproduce.ngrok-free.dev"

# Everything is resolved from this script's own folder so it works no
# matter which directory it is launched from.
$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find ngrok: prefer PATH (winget adds it), fall back to the winget install dir.
$ngrokExe = "ngrok"
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    $wingetNgrok = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "ngrok.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wingetNgrok) { $ngrokExe = $wingetNgrok.FullName } else { throw "ngrok.exe not found. Install with: winget install Ngrok.Ngrok" }
}

# 1. Start the logging receiver in its own window (visible so a crash is obvious).
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectDir'; python -m uvicorn src.main:app --host 127.0.0.1 --port 8000"

# 2. Start the ngrok tunnel in its own window, pinned to the static domain
#    so the public URL is identical on every restart.
Start-Process $ngrokExe -ArgumentList "http", "8000", "--domain=$staticDomain"

# 3. Ask ngrok's local inspection API for the public URL (retry while it boots).
$publicUrl = $null
foreach ($attempt in 1..20) {
    Start-Sleep -Milliseconds 500
    try {
        $tunnels = (Invoke-RestMethod "http://127.0.0.1:4040/api/tunnels" -ErrorAction Stop).tunnels
        $https = $tunnels | Where-Object { $_.public_url -like "https://*" } | Select-Object -First 1
        if ($https) { $publicUrl = $https.public_url; break }
    } catch { }
}

if ($publicUrl) {
    Write-Host ""
    Write-Host "Capture pipeline is UP." -ForegroundColor Green
    Write-Host "TradingView alert webhook URL:  $publicUrl/webhook" -ForegroundColor Cyan
    Write-Host "Alerts are appended to:         $projectDir\logs\raw_alerts.jsonl"
    Write-Host "Live traffic inspector:         http://127.0.0.1:4040"
} else {
    Write-Host "ngrok did not report a tunnel after 10s — check the ngrok window for errors." -ForegroundColor Red
}
