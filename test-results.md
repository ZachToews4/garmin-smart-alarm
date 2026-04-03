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
- per-night plots in `results/*_replay_plot.png`

### 3. Replay harness works
The replay datasets are built from EDF + hypnogram files and include:
- minute-indexed ground-truth sleep stage labels
- derived proxy features for offline experimentation
- scenario evaluation output using a Garmin-constrained 5-minute polling cadence

### 4. Wider multi-scenario replay outcome
Scenario set per night:
- `late_window`
- `mid_window`
- `tight_window`

Total scenarios evaluated:
- **30** (10 nights × 3 scenario shapes)

Current aggregate result from `results/evaluation_batch.json`:
- proposed exact trigger/stage match to oracle snapped-to-5-minute cadence: **21 / 30**
- exact match rate: **0.70**
- proposed trigger inside window: **30 / 30**
- inside-window rate: **1.0**

Interpretation:
- the revised rule is reliably staying inside the intended wake window
- but once the test set was widened, it stopped being perfectly aligned with the earliest oracle-reachable trigger
- several misses are near-misses (same stage, 5–10 minutes later)
- some misses are real quality failures, especially around certain mid-window and late-window nights

### 5. Important failure case found
The wider set surfaced real weaknesses.
Example:
- `SC4081E0` showed cases where the proposed logic fell back to target or delayed too long even though earlier reachable light sleep existed in-window.

That is useful. It means the harness is now doing its job instead of just telling us flattering stories.

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
- per-night plots

## Verification performed
- app compiles successfully with `monkeyc`
- replay harness executes successfully on 10 public real sleep nights
- batch evaluation JSON generated successfully
- widened scenario testing now exposes failure cases instead of hiding them

## Blockers / incomplete
1. The replay harness still uses proxy features derived from PSG channels, not raw Garmin watch exports.
2. Simulator launch on this host currently fails with:
   - `libsoup-ERROR: libsoup2 symbols detected. Using libsoup2 and libsoup3 in the same process is not supported.`
3. The app has not yet been validated on a physical Venu 2 with observed live sensor-history values.
4. The current smart-wake heuristic still needs another refinement pass.
5. Motion/accelerometer-informed logic is not yet wired into the actual app runtime.

## Next recommended steps
1. Analyze the 9 mismatch scenarios and cluster them into true failures vs cadence-near-misses.
2. Refine the heuristic based on those failure modes.
3. Re-run the full 30-scenario batch and look for improvement.
4. Then move toward simulator/runtime or direct watch validation.
