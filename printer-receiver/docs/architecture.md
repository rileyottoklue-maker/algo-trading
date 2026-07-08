# Architecture

To be written from the Printer build guide.

## Roadmap decision — AMENDED 2026-07-05 (same day): trader chose to begin
## indicator rebuilds NOW, starting with SMT, using the calibrated Zone
## Publisher as the architectural template. Order: SMT first (richest
## verification data — 500+ captured vendor payloads with exact swing
## prices/times to calibrate against), IFVG second (15s data scarcity makes
## verification hardest). The vendor indicators stay on the charts during
## calibration; rebuilt streams carry "source":"printer" so both coexist in
## the log. The original counsel (defer to Phase 3) stands recorded below
## for context. The decision boundary is UNCHANGED: detection in TradingView,
## decisions in the server — the rebuilds replicate detection only, never
## strategy conditions.

## Roadmap decision — 2026-07-05: indicator independence is Phase 3, not now
Trader proposed recreating all three closed indicators (as done for Statmap)
and/or porting detection fully to Python, cutting TradingView out. Decision:
- SMT and IFVG are NOT recreated while their payloads deliver everything the
  server needs (verified live). Recreation is the contingency plan for a
  vendor break (template change, revoked access), not current work. The
  Statmap recreation exists because Statmap was BLOCKING (no prices); it
  cost ~1 day of calibration and ended provably-close-not-identical.
- The strategy's condition set stays OUT of Pine. TradingView detects;
  the server decides. Pine cannot be unit-tested, replayed, or made
  idempotent — the decision layer lives in Python only.
- Full Python detection (own data feed, no TradingView) is the correct END
  state and becomes worth building only after the Phase 1 forward log
  (100+ trades) proves the model. The webhook boundary makes it a swap of
  the input adapter, not a rewrite of the decision engine. Same milestone
  unlocks backtesting (what QuantConnect was parked for).

## Committed decisions (record here so they survive until the full doc)

### 2026-07-04 — Zones v2: computed Zone Publisher + Bar Reporter heartbeat (SUPERSEDES the 2026-07-02 decision below)
Manual per-4H transcription (v1 below) was rejected by the trader — a routine
that gets skipped becomes silent bad geometry. Statmap's levels are drawing
objects (not plots), so TradingView's plot-placeholder alerts can't read them
either. Decision: reimplement the statistic ourselves and split the job:

- pine/printer_zone_publisher.pine — runs on the NQ1! continuous 4H chart
  (years of history = enough samples). Recomputes Statmap's public statistic
  (mean + median manipulation/distribution size, percent of open, lookback =
  past 60 4H candles pooled) and webhooks the full zone table at each 4H OPEN.
  Documented exception to the bar-close rule: a deterministic scheduled
  broadcast, fired at the open because the server must hold geometry before
  the candle trades.
- pine/printer_bar_reporter.pine — runs on the NQ1! 1m chart. One OHLC JSON
  webhook per bar close. No inputs, alert created once, never re-created.
- TAP DETECTION MOVES SERVER-SIDE: the server compares each heartbeat bar's
  range against the stored zone bands (wick-touch rule). All tap/validity/
  re-fire logic now lives in testable Python. The heartbeat also serves as
  the server's wall clock for validity windows.
- CALIBRATION GATE: PASSED 2026-07-04. Verified against Statmap's own
  tooltips on the same candle: distribution means within 0.7pt, all
  manipulation values within 2.1pt. Accepted residual: distribution medians
  ±13.4pt (documented in docs/decisions.md — pinned across every testable
  hypothesis; lives in Statmap's private intrabar internals). Final formula
  locked in decisions.md; hypothesis toggles remain in the script but the
  shipped defaults ARE the calibrated configuration.
- Nothing requires the trader's hands after calibration: no transcription,
  no alert re-creation, fully automatic.

### 2026-07-02 — Zone geometry & tap detection via self-authored indicator (SUPERSEDED)
Problem: Statmap alerts carry no prices/symbol (captured fact), so the server
cannot learn zone levels (stop/TP1/TP2) or detect zone taps (setup step 1)
from webhooks, and the server deliberately has NO price feed.

Decision: a self-authored TradingView indicator
(pine/printer_zone_tap_reporter.pine) holds trader-transcribed zone bands as
inputs, detects band entries on bar close, and fires JSON tap alerts carrying
the full zone table. Detection stays on TradingView (where the price feed
lives); the server remains a pure webhook combiner.

Consequences:
- Statmap's own alerts become advisory ("zones refreshed — go transcribe"),
  not machine-consumed signals.
- Trader routine per 4H candle: read Statmap bands → update indicator inputs
  → delete + re-create its alert (TradingView freezes inputs into alerts).
- The transcription is a manual step in the signal path: a typo becomes bad
  geometry. Mitigated by the indicator drawing its bands for visual
  comparison against Statmap before the alert is re-created.
