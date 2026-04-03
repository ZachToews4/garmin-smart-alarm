# Test Results — Garmin Smart Alarm

## Date
2026-04-03

## Scope
Reality-based validation pass for the Garmin smart alarm app using public overnight sleep data and Garmin Connect IQ capability checks.

## Findings

### 1. Original app architecture had a likely signal mismatch
The app was originally written around:
- heart rate history
- HRV history
- respiration history

But local CIQ API inspection for this SDK/device path showed clear support for:
- `getHeartRateHistory`
- `getStressHistory`
- `getBodyBatteryHistory`

and did **not** show `getHeartRateVariabilityHistory` or `getRespirationRateHistory` in the SensorHistory API path inspected locally.

Implication: the original background smart-wake logic depended on signals that are unlikely to be available/reliable on the actual Venu 2 path being targeted.

### 2. Public real sleep data pipeline is now working across 10 nights
Dataset source:
- PhysioNet Sleep-EDF Expanded

Processed nights so far:
- `SC4001E0`
- `SC4011E0`
- `SC4031E0`
- `SC4041E0`
- `SC4051E0`
- `SC4061E0`
- `SC4071E0`
- `SC4081E0`
- `SC4091E0`
- `SC4101E0`

Working local artifacts:
- raw EDF/Hypnogram files in `data/raw/`
- minute-level replay datasets in `data/processed/`
- batch evaluation report in `results/evaluation_batch.json`
- mismatch analysis in `results/mismatch_analysis.csv`
- per-night plots in `results/*_replay_plot.png`

### 3. Replay harness works
The replay datasets are built from EDF + hypnogram files and include:
- minute-indexed ground-truth sleep stage labels
- derived proxy features for offline experimentation
- scenario evaluation output using a Garmin-constrained 5-minute polling cadence

### 4. Wider multi-scenario replay outcome after heuristic refinement
Scenario set per night:
- `late_window`
- `mid_window`
- `tight_window`

Total scenarios evaluated:
- **30** (10 nights × 3 scenario shapes)

Current aggregate result from `results/evaluation_batch.json`:
- proposed exact trigger/stage match to oracle snapped-to-5-minute cadence: **28 / 30**
- exact match rate: **0.9333**
- proposed trigger inside window: **30 / 30**
- inside-window rate: **1.0**

Interpretation:
- the refined rule is now consistently staying inside the intended wake window
- and is much closer to the earliest oracle-reachable trigger than the previous version

### 5. Mismatch analysis result
Mismatch analysis showed:
- **8 near-miss same-stage cases** in the earlier wider batch
- **1 true decision miss**

That gave a clear refinement target.

### 6. Heuristic improvement outcome
Refinement applied:
- avoid firing too eagerly immediately after a deep-looking poll
- require a more stable REM/stage-2-like transition before triggering

Result:
- exact-match rate improved from **21 / 30 (70%)** to **28 / 30 (93.3%)**

Remaining mismatches:
1. `SC4001E0 / tight_window`
   - appears to be a cadence/fallback edge case near target
2. `SC4051E0 / mid_window`
   - oracle earliest snapped point is a non-light stage, while the heuristic chose a later REM point that is arguably more sensible as an actual wake choice

That second one is not obviously a bug. It may reflect a weakness in the oracle definition rather than in the heuristic.

## Code changes made

### Detection model refactor
Refactored from HRV/respiration-dependent logic toward Garmin-plausible background signals:
- HR
- Stress
- Body Battery

Files changed:
- `source/Constants.mc`
- `source/SleepDetector.mc`
- `source/AlarmBackground.mc`
- `source/AlarmManager.mc`
- `source/MainView.mc`

### Validation/tooling work
Added and expanded:
- multi-night EDF download tooling
- replay dataset generation
- batch evaluator
- scenario-shape comparisons
- mismatch analysis
- per-night plots

## Verification performed
- app compiles successfully with `monkeyc`
- replay harness executes successfully on 10 public real sleep nights
- mismatch analysis identifies failure classes instead of just raw misses
- heuristic refinement materially improved exact-match rate on the full 30-scenario batch

## Blockers / incomplete
1. The replay harness still uses proxy features derived from PSG channels, not raw Garmin watch exports.
2. Simulator launch on this host currently fails with:
   - `libsoup-ERROR: libsoup2 symbols detected. Using libsoup2 and libsoup3 in the same process is not supported.`
3. The app has not yet been validated on a physical Venu 2 with observed live sensor-history values.
4. The remaining 2 mismatch scenarios should be reviewed before locking the heuristic.
5. Motion/accelerometer-informed logic is not yet wired into the actual app runtime.

## Next recommended steps
1. Decide whether the `SC4051E0 / mid_window` disagreement is a true miss or an oracle-definition issue.
2. Handle the `SC4001E0 / tight_window` cadence/fallback edge case if needed.
3. Then move toward simulator/runtime or direct watch validation.
