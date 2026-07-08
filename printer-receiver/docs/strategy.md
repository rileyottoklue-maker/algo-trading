# Strategy

To be written from the Printer build guide.

## Confirmed rulings from the trader (record here so they survive until the full doc)

- 2026-07-02 — SMT timeframes: the model runs TWO SMT streams, 15m and 1m.
  EITHER one qualifies as the SMT condition on its own (not a two-stage
  HTF-arms-then-LTF-confirms gate). Often both are present at the same setup.
- 2026-07-02 — Stop selection with multiple SMTs: when both a 15m and a 1m
  SMT are present, the 15m SWING IS THE STOP.
- 2026-07-02 — Partial invalidation: if the 1m SMT breaks while the 15m SMT
  is intact, the setup is STILL ARMED — the 15m takes priority.
  Implied (unconfirmed): if the 15m SMT breaks, the setup dies even if a 1m
  SMT remains intact, since the 15m swing is the stop.
- 2026-07-02 — Stop placement when ONLY the 1m SMT is present: the stop goes
  at the EXTREME of the two SMT swing points — the lowest low (bullish) /
  highest high (bearish). In payload terms: min(start_price, end_price) for
  bullish, max(...) for bearish.
- 2026-07-02 — Stop placement for the 15m SMT: the extreme-of-both rule does
  NOT apply — the stop anchors to the CURRENT swing leg.
- OPEN (must be payload-grounded before the state machine): does "current
  swing leg" for the 15m stop mean exactly the second swing in the formation
  alert (end_price — fixed at alert time)? The server has NO price feed; if
  the anchor is the extreme of a still-developing leg, the webhook cannot
  supply it and another mechanism is needed.
- 2026-07-02 — Zones are BANDS, not lines: the Statmap box spans mean/median
  "and everything in between". A tap is a WICK TOUCH anywhere in the band
  (bar range overlaps the band), evaluated at bar close.
- 2026-07-02 — Tap/SMT order independence: a zone tap starts the search for
  an SMT, OR — if a qualifying SMT is already present when the tap happens —
  the pair arms immediately. Either order arms; the 15s IFVG then confirms
  entry. The state machine must NOT assume tap-before-SMT.
- 2026-07-05 — Arm patterns REFINED (trader): the valid tap/SMT structures are
  (a) tap first, SMT forms AFTER the tap or with its swings INSIDE the zone;
  (b) the SMT STRADDLES the tap — the SMT's FIRST swing is itself the zone
  tap, and the arm completes when the second swing confirms the divergence.
  In all patterns the 15s IFVG is the final entry confirmation.
  Expressibility check: the server can verify each pattern from existing
  payloads — SMT formations carry both legs' prices/times, ZONES carries the
  band, BARS supplies tap detection. No new stream needed.
- 2026-07-05 — Leg question RESOLVED (trader): EITHER SMT leg tapping the
  zone qualifies — it doesn't matter which. Rationale, verbatim spirit: the
  SMT is the reversal indication; since it taps the zone (a probable reversal
  zone), the 15s IFVG is then the entry trigger. Server check stays: either
  swing (start or end) inside/touching the band qualifies the SMT.
- 2026-07-05 — IFVG origination rule (trader): the originating FVG must
  print ON THE LEG THAT MAKES THE SMT (the displacement into the zone), and
  the trigger is the close back over/under that gap (the inversion). Server
  check: the gap's creation time falls within the SMT leg's window (IFVG
  payloads carry gap_time_ny for this). Direction coherence is inherent:
  only a down-leg gap inverts into a bullish trigger and vice versa.
- OPEN (strategy-doc session): does an SMT fully formed BEFORE the tap, with
  neither leg touching the zone, still arm when price taps later (per the
  2026-07-02 ruling)? The trader's reversal rationale suggests SMT-zone
  contact matters; the UNDECIDED "SMT validity window" parameter governs
  staleness either way.
- 2026-07-02 — SMT zone membership: an SMT qualifies even when only ONE of
  its two legs taps the zone. Server check: either swing (start_price or
  end_price) inside the band qualifies.
- 2026-07-02 — Statmap zones refresh EVERY 4H candle: the trader re-transcribes
  band levels into the Zone Tap Reporter and re-creates its alert each 4H
  candle (TradingView freezes inputs into alerts at creation — captured fact).
