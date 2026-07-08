"""Phase 0 logging receiver for The Printer.

This server does exactly one thing: capture every incoming webhook alert
exactly as it arrived, so docs/payloads.md can be filled from real fired
alerts. It makes NO decisions, sends NO orders, and contains NO condition
logic — by design. Nothing gets built against an assumed payload.
"""

import json
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, Request

# The capture log lives in logs/ next to src/, resolved from this file's
# own location so the server writes to the same place no matter which
# directory it was launched from.
LOG_FILE_PATH = Path(__file__).resolve().parent.parent / "logs" / "raw_alerts.jsonl"

app = FastAPI()


@app.post("/webhook")
async def receive_webhook(request: Request):
    # Read the raw bytes before any parsing, because the whole point of
    # Phase 0 is to capture what the indicators actually send — including
    # bodies that are not valid JSON.
    raw_body_bytes = await request.body()

    # Decode with errors="replace" so a malformed byte can never crash the
    # receiver or cause an alert to go unlogged.
    raw_body_text = raw_body_bytes.decode("utf-8", errors="replace")

    # Attempt a JSON parse purely as a convenience for reading the log
    # later. Failure is tolerated (parsed_json stays None) because we must
    # never assume the payload format before it is captured.
    try:
        parsed_json = json.loads(raw_body_text)
    except json.JSONDecodeError:
        parsed_json = None

    # Record the client IP so real TradingView alerts can be told apart
    # from local test posts when reviewing the capture log.
    client_ip = request.client.host if request.client else None

    # One self-contained JSON object per line (JSONL) so the log can be
    # appended to forever and replayed line by line by future test tooling.
    log_entry = {
        "received_at_utc": datetime.now(timezone.utc).isoformat(),
        "client_ip": client_ip,
        "content_type": request.headers.get("content-type"),
        "raw_body": raw_body_text,
        "parsed_json": parsed_json,
    }

    # Create logs/ if it is missing and append (never overwrite), so no
    # captured alert is ever lost to a missing folder or a truncated file.
    LOG_FILE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE_PATH.open("a", encoding="utf-8") as log_file:
        log_file.write(json.dumps(log_entry) + "\n")

    # Acknowledge receipt and nothing more — no decisions, no orders.
    return {"status": "received"}
