# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# NQ Algo - 4H PO3 Intermediate Model

## Project
Intraday algorithmic trading system for NQ and ES futures built on QuantConnect using Python. This algo is a direct translation of a discretionary ICT-based model using the Power of Three (PO3) framework on the 4-hour timeframe.

## Instruments
- Primary: NQ (E-mini Nasdaq futures)
- SMT Pair: ES (E-mini S&P 500 futures)
- Session: NY Open (8:30–16:10 EST), secondary setup at 14:00 EST
- No overnight positions ever

## Model Logic (in order)
1. Identify accumulation zone: high and low of 8:30–9:30 EST range
2. Identify manipulation leg: initial directional move off 4H candle open
3. Calculate STDV levels from manipulation swing high/low at -2, -2.25, -2.5, -4, -4.25, -4.5
4. Identify 15m PDAs: Order Blocks, Fair Value Gaps, previous highs/lows
5. Wait for STDV level to align with a 15m PDA
6. Wait for HTF SMT divergence (NQ vs ES on 15m) to confirm at that zone
7. Wait for LTF SMT divergence (NQ vs ES on 1m) to confirm after HTF
8. Enter on CISD (Change in State of Delivery) by market or limit order
9. Stop placed at HTF SMT swing point
10. TP1 at nearest STDV + PDA confluence, TP2 at 4H open / daily open
11. Move stop to breakeven after TP1 hit

## Stack
- QuantConnect (Lean engine) — backtesting and live execution
- Python — all algo code
- Obsidian vault (NQ Algo) — model and confluence documentation

## Obsidian Vault Structure
- 00-model: strategy overview and checklist
- 01-confluences: exact definitions of every signal condition
- 02-algo: translation log, all code decisions documented
- 03-backtest: every backtest run logged with parameters and results
- 04-journal: every manual trade logged as a data point

## Code Rules
- Every signal condition must have a corresponding definition in 01-confluences
- Every parameter must be documented in 02-algo Translation Log before coding
- Every change must be backtested and logged in 03-backtest before going live
- Variable names must be explicit (accumulation_high not ah)
- Every signal condition gets a plain English comment explaining WHY it exists
- No magic numbers — all thresholds defined as named constants at the top of the file

## Key Translation Challenges
- Manipulation leg detection: hardest component, requires swing point logic
- CISD: requires market structure context, may need discretionary override initially
- SMT: comparative price logic between NQ and ES at the same timestamp
- OB detection: requires impulse move detection on 15m bars

## Open Questions (resolve before coding each component)
- How many bars back for swing high/low detection?
- What defines an impulse move for OB detection?
- CISD confirmation on 1m or 15m?
- Minimum STDV zone width to be considered valid?
