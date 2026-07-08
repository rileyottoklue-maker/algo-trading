# CLAUDE.md — The Printer (Webhook Execution System)

## What this project is
A deterministic execution layer for an ICT-based NQ futures strategy.
Three closed-source TradingView indicators plus one self-authored
zone-tap indicator fire alerts as webhooks.
A FastAPI server (this repo) receives them, holds state, applies the
compound conditions, and on a valid setup sends ONE execution webhook
to a broker relay, which places a bracket order on Tradovate.

You (Claude Code) are the build-time compiler of this system.
You are NEVER in the live path of a trade. No LLM is.
The strategy in plain English lives in docs/strategy.md — the server
is its compiled, deterministic form.

## The pipeline
TradingView alerts → webhooks → FastAPI server (decision + state)
→ execution webhook → relay (sizing + brackets) → Tradovate (fills)

Exits (stop, TP1, TP2) live at the broker as bracket orders.
The server must never be required to be alive for a position to exit.

## Signal stack (detection is outsourced to closed indicators)
- Statmap: defines H4 manipulation and distribution zones, both directions
  (alerts advisory-only — zone geometry enters via ZONES; docs/architecture.md)
- ZONES (self-authored Zone Publisher, 4H): COMPUTED zone geometry
  (reimplemented Statmap statistic; calibration-gated), broadcast at 4H open
- BARS (self-authored Bar Reporter, 1m): OHLC heartbeat; server-side tap
  detection + wall clock
- SMT: divergence across correlated index futures (NQ vs ES/YM)
- IFVG (15-second): final confirmation trigger
The server does NOT detect these concepts. It only combines them:
sequencing, zone membership checks, validity windows, invalidation.

## Setup logic (bullish; bearish is the mirror)
1. Price wick-taps the H4 manipulation zone band (any touch, at bar close)
2. Bullish SMT (15m or 1m — either qualifies alone) present at that zone;
   tap and SMT may arrive in EITHER order → setup ARMED
   (see docs/strategy.md order-independence ruling, 2026-07-02)
3. Server pre-stages full order: long, stop at SMT low,
   TP1 = opposing manipulation zone, TP2 = opposing distribution zone
4. 15s bullish IFVG fires while setup still valid → RELEASE
5. One execution webhook out. Done. Log everything.

## Source of truth files (read these, in this order)
- docs/strategy.md — the model as precise if-then rules
- docs/payloads.md — EXACT JSON each alert really sends (captured, never guessed)
- docs/architecture.md — decision/execution boundary
- docs/decisions.md — every parameter's committed value

## Hard rules
- Nothing is built against an assumed payload. payloads.md is filled
  from real fired alerts before any state machine code is written.
- Money-touching guardrails live in CODE and CONFIG, not in this file.
  A test run must be structurally unable to reach the live relay
  (separate URLs, an environment flag, and a dry-run default).
- Every alert handler is idempotent — duplicate alerts must not double-fire.
- All machine-consumed alerts are "once per bar close." No intrabar signals.
  (Exception: Statmap's vendor alerts fire intrabar — tolerated only because
  they are advisory and never machine-consumed. See docs/payloads.md.)
- Everything is anchored to New York time. State it once, use it everywhere.
- No parameter exists without a line in docs/decisions.md.
- Explicit variable names (manipulation_zone_high, not mzh).
- Every condition gets a plain English comment explaining WHY.
- No magic numbers — named constants only, each traceable to decisions.md.

## Build phases (static until stats)
- Phase 0 (NOW): logging receiver. Capture real payloads. Fix plumbing
  against fake and then real alerts. Paper relay only. Change freely.
- Phase 1: frozen forward test, micro size, one setup, constants locked.
  The log is the deliverable, not the profit. Changes reset the sample.
- Phase 2: data-earned changes only, from a log of 100+ trades.

## Current build status
- FIRST ALGO RUN (2026-07-05, capture-only): alerts live for vendor SMT,
  vendor IFVG, printer Zone Publisher, printer SMT Publisher (+ Bar Reporter
  heartbeat; combined SMT+IFVG RELEASE stream recommended). No decision
  engine exists yet — the log is the run. Offline replay of the captured
  streams against docs/strategy.md rulings produces the first simulated
  trade journal (Phase 0 → 1 bridge).
- Phase 0: logging receiver LIVE, capturing via ngrok static domain
- CAPTURE GOAL MET (2026-07-02): all three indicators captured, all event
  types, real formats documented in docs/payloads.md
  - IFVG: fixed text, Potential + Active variants; Active carries
    Entry/Stop/BESW numbers (regex-parseable)
  - Statmap: fixed text event ping (`[+]/[-] 4H Manipulation/Distribution`),
    NO prices/symbol ever (confirmed not editable); fires on zone creation
    (tentative)
  - SMT: custom JSON templates verified live — formation + breakage parse
    cleanly, carry swing prices + literal pair tag ("NQ-ES")
- All indicators send intermittent exact duplicates → idempotency mandatory
- Remaining minor unknown: non-empty {{fvgSuffix}} expansion in SMT formation
- Zone levels + zone-tap: v2 DECIDED 2026-07-04 (docs/architecture.md) —
  Zone Publisher (4H, computed geometry) broadcasts levels at each 4H open;
  Bar Reporter (1m heartbeat) feeds server-side tap detection. Manual
  transcription rejected. CALIBRATION PASSED 2026-07-05: per-slot 60-day
  windows, wick + expansion-from-open, mean + standard median — verified 1:1
  against Statmap across the full historical trail (trader confirmed).
  Awaiting: alerts created + first real ZONES/BARS captures
  (docs/payloads.md).
- SMT runs as TWO alert streams: 15m (HTF) and 1m (LTF), both JSON —
  the timeframe field distinguishes them server-side
- SMT ruling (trader-confirmed 2026-07-02): EITHER stream qualifies alone —
  not a two-stage gate. When both are present, the 15m swing is the stop
  (logged in docs/decisions.md). Partial invalidation ruled 2026-07-02:
  a 1m SMT break with the 15m intact does NOT invalidate (15m priority).
  Still open: confirm a 15m break kills the setup even with an intact 1m
  (implied, unconfirmed — docs/strategy.md).
- Next: write docs/strategy.md as if-then rules, then the state machine

## What we are NOT doing
- No QuantConnect / Lean (parked, may return later for backtesting)
- No statistical/TA/ML libraries — this is a parser, not a regression
- No LLM at runtime, ever
- No prop firm constraints (own funded account confirmed)

## Testing approach
- Replay-based strategy validation: TradingView bar replay generates
  hand-marked setups → each becomes a sequence of fake webhook payloads
  → fed to the state machine test suite. Fake payloads must match
  captured real payloads byte-for-byte in structure.
- 15s replay history is limited — forward log remains ground truth.
