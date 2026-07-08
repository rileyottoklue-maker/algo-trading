# algo-trading

Workspace for **The Printer** — a deterministic, webhook-based execution layer
for an ICT-based NQ futures strategy.

> ⚠️ **The active project is [`printer-receiver/`](printer-receiver/).**
> The `CLAUDE.md` at *this* root describes a **retired QuantConnect build** and
> must not be acted on. The real project instructions live in
> [`printer-receiver/CLAUDE.md`](printer-receiver/CLAUDE.md). When working with
> Claude Code, open it at the `printer-receiver/` directory so it loads the
> correct instructions.

## What's here

```
printer-receiver/
├── CLAUDE.md          # real project instructions (read this, not the root one)
├── docs/
│   ├── strategy.md    # the model as if-then rules + dated trader rulings
│   ├── architecture.md# decision/execution boundary, roadmap decisions
│   ├── payloads.md     # EXACT captured JSON per indicator stream
│   └── decisions.md   # every parameter's committed value + rationale
├── pine/              # self-authored TradingView indicators (the detection layer)
│   ├── printer_zone_publisher.pine   # calibrated Statmap-equivalent zones
│   ├── printer_smt_publisher.pine    # SMT divergences (LuxAlgo-derived core)
│   ├── printer_ifvg_publisher.pine   # combined SMT-leg + IFVG release engine
│   └── printer_bar_reporter.pine     # 1m OHLC heartbeat (server clock + tap feed)
├── src/main.py        # Phase 0 FastAPI logging receiver
└── logs/raw_alerts.jsonl  # captured payload log (the Phase 0 deliverable)
```

## Current state (as of last session, 2026-07-05)

- **Phase 0 (capture) — running.** All three closed indicators have printer-owned
  rebuilds streaming JSON beside their vendor originals. Zone geometry is
  calibrated 1:1 against Statmap. First live algo run is capture-only:
  **the log is the run** — no decision engine exists yet.
- **Next:** offline-replay the captured streams against `docs/strategy.md` to
  produce the first simulated trade journal, then write the state machine.

## Resume on another device

1. **Clone**
   ```
   git clone <this repo> algo-trading
   cd algo-trading/printer-receiver
   ```
2. **Python receiver**
   ```
   pip install fastapi uvicorn
   python -m uvicorn src.main:app --host 127.0.0.1 --port 8000
   ```
3. **ngrok tunnel** — the static domain `gleaming-public-reproduce.ngrok-free.dev`
   is tied to the **ngrok account**, not the machine, so the webhook URL stays
   the same across devices (only one device may run the tunnel at a time):
   ```
   winget install Ngrok.Ngrok      # or download from ngrok.com
   ngrok update                     # winget's build may be below the account minimum
   ngrok config add-authtoken <YOUR_TOKEN>   # from dashboard.ngrok.com — NOT stored in this repo
   ngrok http 8000 --domain=gleaming-public-reproduce.ngrok-free.dev
   ```
   On Windows, [`printer-receiver/start_capture.ps1`](printer-receiver/start_capture.ps1)
   launches the receiver + tunnel together.
4. **TradingView alerts** keep pointing at
   `https://gleaming-public-reproduce.ngrok-free.dev/webhook` — no change needed,
   because the domain is reclaimed by whichever device holds the tunnel.
5. **Claude Code** — open the session at `printer-receiver/`. The full decision
   history is in `docs/decisions.md` and `docs/strategy.md`; this session's
   working memory is summarized there (the separate Claude Code memory store is
   machine-local and does not travel with the repo).

## Webhook pipeline

```
TradingView alerts → webhook → FastAPI receiver (this repo, logs everything)
→ [Phase 1+] decision engine → execution webhook → broker relay → Tradovate
```

Exits (stop, TP1, TP2) live at the broker as bracket orders. No LLM is ever in
the live path of a trade.
