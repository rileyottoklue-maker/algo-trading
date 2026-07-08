# Alert Payloads — CAPTURED, NEVER GUESSED

## Current alert configuration (production, as of 2026-07-02 ~13:30 NY)
- Statmap: 4H chart — default fixed text alerts
- SMT: TWO alerts, both with the custom JSON templates (formation + breakage):
  - 15-minute (HTF confirmation stream)
  - 1-minute (LTF confirmation stream)
  The `timeframe` field distinguishes them server-side. The 15m token wording
  is NOT yet captured (expected "15 min(s)" — confirm on first fire).
- IFVG: 15-second chart (this IS its production timeframe) — default text
- Earlier low-timeframe captures (0.25m Statmap) were format tests only;
  1m SMT captures remain valid — 1m is now a production stream.

## Statmap

Indicator identity: **OHLC Statistical Mapping [Pro+]** (Toodegrees x Joshuuu,
closed source). Mechanics per the official description: for each chosen
candle timeframe (up to 5 at once) it plots LINE/LABEL-based statistical
levels — historical average and median manipulation and distribution
projections from the candle's open, both directions, refreshed every candle.
ICT framing: manipulation = the wick opposing the candle's eventual close;
distribution = the expansion after it.

How the trader uses it (ruling, 2026-07-02): the "zone" is the BAND between
the mean and median level of the same type/direction — "everything in
between". So the Zone Tap Reporter's band high/low inputs are transcribed
from the mean/median line pair.

`[+]` / `[-]` reading — CORRECTED 2026-07-04 from the live chart: the sign
names the CANDLE-DIRECTION SCENARIO, not the side of price. A bullish candle
manipulates down first, so `[+] Manipulation` sits BELOW the open and
`[+] Distribution` ABOVE it; `[-]` mirrors. (The earlier "upside/downside"
reading was wrong.) The indicator also plots the average
TIME at which manipulation/distribution phases historically complete —
not consumed by the system yet, but a candidate input for the "zone tap
expiry" / validity-window parameters later.

Its alert behavior is NOT documented by the vendor; our creation-fire
reading below stays tentative. Since the Zone Tap Reporter now owns tap
detection and geometry, Statmap's own alerts are ADVISORY ONLY
("levels refreshed — go transcribe") and the open question is low-stakes.

First capture 2026-07-02 — from a deliberate 15-SECOND-CHART TEST fire, not a real H4 event. Format is real; the `0.25m` timeframe token reflects the test chart. 5 alerts arrived in one ~150ms burst at 17:01:23 UTC from TradingView webhook IPs.

Transport: `Content-Type: text/plain; charset=utf-8`. Plain text, not JSON.

Observed messages (verbatim, complete — this is the ENTIRE body):
```
[-] 0.25m Distribution
[-] 0.25m Manipulation
[+] 0.25m Manipulation
[-] 0.25m Distribution
```

Structure: `[sign] <timeframe> <zone type>` where sign is `+` or `-` and zone
type is `Manipulation` or `Distribution`.

**Real-chart token CAPTURED 2026-07-02 17:17 UTC: `4H`** — e.g. `[-] 4H Distribution`,
`[+] 4H Manipulation`. Note the token format is NOT a consistent unit scheme
(15s chart printed `0.25m`, H4 chart prints `4H`). The server should whitelist
the exact string `4H` and ignore all other timeframe tokens.

Note: the 4H pair above arrived as a 6ms burst at 13:17 NY — mid-bar on a 4H
chart, coinciding with the alerts being (re)created. Consistent with fires at
alert creation for zones present on the chart; another reason handler logic
must tolerate replay-like bursts that aren't fresh market events.

**GATING QUESTION ANSWERED: the payload carries NO zone levels.** No prices, no symbol, no timestamp, no zone boundaries — nothing numeric except the timeframe token.

**FORMAT IS FINAL (confirmed 2026-07-02):** the alert message is NOT editable in the TradingView alert dialog — Statmap uses author-fixed alert() text, so no placeholders ({{close}}, {{ticker}}) can ever be injected. Architectural consequence: zone price levels can NEVER arrive via the Statmap webhook. The Statmap alert is an event trigger only; zone levels enter the system through the self-authored Zone Tap Reporter (RESOLVED 2026-07-02 — see the ZONES section below and docs/architecture.md).

**Duplicates observed:** `[+] 0.25m Manipulation` arrived twice ~140ms apart, `[-] 0.25m Distribution` twice. With no unique ID in the payload, idempotency must key on (raw_body + time window). This is live evidence for the CLAUDE.md idempotency hard rule.

Fire semantics (REVISED 2026-07-03 after a 24h natural sample): 11 real 4H
fires arrived at IRREGULAR times (18:04:38, 22:36:55, 00:58:23, 02:08:48,
03:30:15, 06:03:48 UTC, ...) — nowhere near 4H bar closes and not on any
bar-close grid. This is consistent with the vendor description ("levels
provide information when price trades THROUGH them"): the alerts appear to
fire INTRABAR when price crosses a level. The earlier both-direction bursts
were alert-(re)creation artifacts, not the normal mode.

Two consequences:
- Statmap's own alerts violate the project's once-per-bar-close rule (vendor
  alert() calls, not controllable). Acceptable ONLY because they are
  advisory — no machine-consumed stream may behave this way.
- A cross alert still says nothing about WHICH price level was crossed;
  the ZONES indicator remains the sole source of tap + geometry truth.

Open questions (low-stakes, advisory stream):
- Why did one bar-close burst produce 5 alerts (multiple zones? duplicate delivery?)

## SMT

CAPTURED 2026-07-02 — from a 1-MINUTE-CHART TEST fire ("1 min(s)" token), not the model's 15m HTF context. One capture so far, bullish only.

Transport: `Content-Type: text/plain; charset=utf-8`. Plain text, not JSON — and MULTI-LINE (contains newlines; the only multi-line payload of the three indicators).

Observed message (verbatim, complete):
```
Bullish 1 min(s) SMT Formed
From: 30016 @ 06-30 09:28:00 - 29414.75 @ 07-02 13:01:00
Duration: 51h 33m
```

Structure:
- Line 1: `<Bullish|Bearish> <timeframe> SMT Formed` (both directions captured)
- Line 2: `From: <price> @ <time> - <price> @ <time>` — the two swing points of
  the divergence. Times are New York time (13:01 NY = 17:01 UTC ✓), no year.
- Line 3: `Duration: ...`

**PARSER LANDMINE — timestamp and duration formats are CONDITIONAL:**
- Swings on a PRIOR day: `29938.25 @ 06-29 20:32:00` (MM-DD HH:MM:SS)
- Swings SAME DAY as the alert: `29469.5 @ 13:00:00` (HH:MM:SS only — date dropped)
- Duration: `64h 33m` when hours exist, but just `7m` under an hour
- Prices print minimal decimals: `30016`, `29387.5`, `29469.5`

**SMT also sends exact duplicates** — the same formation alert arrived twice
(~20–200ms apart) on two occasions. Same idempotency implication as Statmap.

**KEY FINDING: SMT DOES carry swing prices as numbers.** The second price
(29414.75) matched the concurrent IFVG Active alert's Stop price exactly —
consistent with it being the near swing that formed the divergence, i.e. the
model's stop placement level ("stop at SMT low"). If confirmed, the stop can
come straight from this webhook; only TP1/TP2 (zone levels) need another source.

**TEMPLATES ARE USER-EDITABLE (confirmed 2026-07-02).** Unlike Statmap, the SMT
indicator exposes its alert messages as editable templates with author-defined
tokens. Defaults as provided by the indicator:

Formation alert:
```
{{type}} {{timeframe}} SMT Formed
From: {{startPrice}} @ {{startTime}} - {{endPrice}} @ {{endTime}}
Duration: {{duration}}{{fvgSuffix}}
```

Breakage alert (exists; was initially deactivated, being activated for capture):
```
{{type}} {{timeframe}} SMT Broken from {{smtTime}}
```

Known tokens: type, timeframe, startPrice, startTime, endPrice, endTime,
duration, fvgSuffix (expansion unknown), smtTime.

**JSON TEMPLATES DEPLOYED — BREAKAGE CAPTURED, FORMATION STILL PENDING.**

Breakage, CAPTURED 2026-07-02 17:22 UTC (1m test chart), verbatim:
```json
{"indicator":"SMT","event":"broken","pair":"NQ-ES","type":"Bearish","timeframe":"1 min(s)","smt_time":"07-02 13:17:00"}
```
- TradingView set `Content-Type: application/json; charset=utf-8` — it detects
  valid JSON in the message and switches the header. parsed_json populated.
- The literal `"pair":"NQ-ES"` tag survived — instrument-pair gap closed.
- `{{smtTime}}` included the date (`07-02`) even for a SAME-DAY time — differs
  from the default template's embedded times, which dropped same-day dates.
  Do not assume startTime/endTime behave the same until the formation JSON
  is captured.

Formation, CAPTURED 2026-07-02 17:24 UTC (1m test chart), verbatim:
```json
{"indicator":"SMT","event":"formed","pair":"NQ-ES","type":"Bearish","timeframe":"1 min(s)","start_price":"29482.25","start_time":"13:17:00","end_price":"29482.75","end_time":"13:22:00","duration":"5m","fvg":""}
```
- Parses cleanly; Content-Type application/json; prices arrive as string floats.
- `{{fvgSuffix}}` expanded to EMPTY STRING here. Its non-empty expansion is
  still unobserved — presumably populated when the SMT involves an FVG. It is
  isolated in its own JSON string field, so it can only break parsing if it
  ever contains a double-quote character. THE one remaining format unknown;
  treat `fvg` as opaque text until a populated capture exists.
- **Conditional date behavior CONFIRMED in the tokens:** same-day
  `{{startTime}}`/`{{endTime}}` drop the date (`13:17:00`) while `{{smtTime}}`
  keeps it (`07-02 13:17:00`). Prior-day start/end times include `MM-DD`
  (seen in default-template captures). The time parser must accept both
  forms for start/end times.
- Duration token is conditional as seen before (`5m` vs `64h 33m`).
- Cross-check: this formation's start (13:17:00 @ 29482.25) is the same swing
  the earlier breakage referenced (`smt_time: 07-02 13:17:00`) — consistent
  event chain.

Open questions (do not build until answered):
- What does {{fvgSuffix}} expand to? (If it can contain quote characters it
  could break a JSON template — the tolerant receiver will show us.)
- Do custom-token expansions ever contain commas/quotes (e.g. prices >999
  with thousands separators)?
FORMAT MATRIX COMPLETE (2026-07-03, 24h sample of 498 JSON alerts): all 8
combinations captured — Bullish/Bearish × formed/broken × "1 min(s)" /
"15 min(s)". The 15m timeframe token is confirmed: `15 min(s)`.
{{fvgSuffix}} was empty in ALL 285 captured formations — still never
observed non-empty.

- Is {{endPrice}}/endTime always the NEAR swing (= the stop level)?
- Prices can print with no decimals (`30016`) — parse as float, not by
  decimal-format assumption.
- Is SMT breakage the invalidation event for an ARMED setup? (Strategy
  question for docs/strategy.md, but the capture decides what's possible.)

## IFVG

CAPTURED 2026-07-02 (8 real alerts, NQ1!, via TradingView webhook IPs 34.212.75.30 / 52.32.178.7).

Transport: `Content-Type: text/plain; charset=utf-8`. Body is PLAIN TEXT, not JSON — `parsed_json` is null on every capture. Parsing will be string/regex-based.

Two message formats observed:

**Format 1 — "Potential" (no levels):**
```
Potential Bearish IFVG (15S) on NQ1!
Potential Bullish IFVG (15S) on NQ1!
```

**Format 2 — "Active" (carries numeric levels):**
```
Active Bearish IFVG (15S) on NQ1! - Entry: 29522.25, Stop: 29547.25, BESW: 29504.00
Active Bullish IFVG (15S) on NQ1! - Entry: 29523.50, Stop: 29504.50, BESW: 29538.50
```

Observed pattern: "Potential" fires first, "Active" follows (gap ranged from ~0s to ~60s in captures). Both directions observed for both formats.

Open questions (do not build until answered):
- What does BESW stand for? (Break-even swing? Confirm with the trader.)
- Is "Active" the only release-relevant event, or does "Potential" matter for state?
- Is the `(15S) on NQ1!` suffix stable across symbols/timeframe settings?

## ZONES (self-authored: Printer — StatMap Zone Publisher)

PROPOSED — NOT YET CAPTURED (v2, 2026-07-04; the v1 "tap" payload from the
deprecated Zone Tap Reporter was never deployed and is superseded). We author
this indicator (pine/printer_zone_publisher.pine), so the format is designed
rather than discovered — but per house rules nothing is built against it
until a real fire is captured here verbatim.

Purpose: publishes COMPUTED zone geometry (reimplemented Statmap statistic,
GATED on 1:1 calibration — docs/architecture.md). One fire per 4H candle at
the candle OPEN (documented exception to the bar-close rule). Tap detection
happens server-side against the BARS heartbeat.

Designed payload (single line; shown wrapped):
```json
{"indicator":"ZONES","event":"levels","symbol":"NQ1!","chart_timeframe":"240",
 "h4_open":"...","h4_open_time_ny":"YYYY-MM-DD HH:MM:SS","slot":"0-5",
 "zones":{"plus_manipulation":{"enabled":true,"high":"...","low":"..."},
          "minus_manipulation":{...},"plus_distribution":{...},
          "minus_distribution":{...}},
 "config":{"lookback":"60","percent":true,"per_slot":false,"direction_split":true,"window_then_split":true,"full_range_distribution":true}}
```

Parser contract (designed edge cases the server MUST honor):
- Zone keys follow STATMAP'S convention: the sign is the candle-direction
  scenario, so `plus_manipulation` is BELOW the 4H open (bull setup taps it)
  and `minus_manipulation` ABOVE; distributions mirror. Do not assume
  plus = above.
- When a zone has no historical samples, "high"/"low" are the literal string
  "na" — not null, not omitted: `{"enabled":false,"high":"na","low":"na"}`.
  Parse prices only after checking they are not "na".
- "enabled" means sample count >= minimum_samples, NOT price presence — a zone
  can be "enabled":false while still carrying numeric high/low (when
  0 < n < minimum). Gate on "enabled", never on whether prices parse.

## SMT-P (self-authored rebuild: Printer — SMT Publisher)

PROPOSED — IN CALIBRATION (2026-07-05). Drop-in rebuild of the vendor SMT
stream: same field names, cleaner values. Differences from the vendor stream:
- carries `"source":"printer"` (the vendor stream has no source field)
- start/end/smt times are ALWAYS full "yyyy-MM-dd HH:mm:ss" NY (the vendor's
  same-day date-dropping quirk is deliberately not replicated)
- `fvg` is always "" (vendor's non-empty expansion never observed)
- prices are mintick-formatted with fixed decimals (e.g. "30016.00"), unlike
  the vendor's minimal-decimal strings ("30016", "29387.5") — compare prices
  NUMERICALLY during the parallel-run diff, never as strings
Both streams coexist in the log during the parallel-run calibration; the
server distinguishes them by the source field. Formation/breakage semantics
and detection parameters are PROPOSED (docs/decisions.md) until the rebuild's
detections match the captured vendor stream.

## IFVG-P (self-authored rebuild: Printer — IFVG Publisher)

PROPOSED — IN CALIBRATION (2026-07-05, combined SMT+IFVG engine). Semantics:
the SMT layers (1m+15m) define the SMT leg; the candidate gap is the EXTREME
15s FVG on that leg (lowest for bullish, highest for bearish); "active" =
the RELEASE, a 15s close back through the candidate. The vendor's "Potential"
stage is not replicated. smt_time_ny = the arming SMT's formation time;
gap_time_ny = the candidate gap's creation. Optional raw streams carry
timeframe "1m"/"5m"/"15m" with na prices. Numbers: entry = confirming close;
stop = extreme of the lookback swing; besw = nearest held 1m pivot on the
profit side (BESW acronym still unconfirmed by the trader).

Designed payload:
```json
{"indicator":"IFVG","event":"active","source":"printer","type":"Bullish",
 "symbol":"NQ1!","timeframe":"15S","gap_top":"...","gap_bottom":"...",
 "gap_time_ny":"YYYY-MM-DD HH:MM:SS","entry":"...","stop":"...","besw":"...",
 "bar_close_time_ny":"YYYY-MM-DD HH:MM:SS"}
```
gap_time_ny = the originating FVG's creation time — the server needs it for
the trader's origination rule (the gap must print on the SMT-making leg;
docs/strategy.md 2026-07-05).
The vendor text stream keeps flowing in parallel; the server distinguishes
by format (JSON + source field vs plain text).

## BARS (self-authored: Printer — Bar Reporter)

PROPOSED — NOT YET CAPTURED. One JSON webhook per 1-minute bar close from the
NQ1! chart: the server's price feed for tap detection and its wall clock for
validity windows.

Designed payload:
```json
{"indicator":"BARS","event":"bar_close","symbol":"NQ1!","chart_timeframe":"1",
 "open":"...","high":"...","low":"...","close":"...",
 "bar_close_time_ny":"YYYY-MM-DD HH:MM:SS"}
```

Expected volume: ~1,380/day (23h session). Both streams await first real
fires — which also verify TradingView passes nested JSON intact and flips
Content-Type to application/json as it did for the SMT payloads.

## Raw capture samples

See logs/raw_alerts.jsonl for the verbatim captures backing this file
(lines 4–11: IFVG; lines 12–16: Statmap 15s test). Lines 1–3 are local/E2E
plumbing tests, not indicator alerts.
