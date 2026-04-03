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

### 2. Public real sleep data pipeline is now working across multiple nights
Dataset source:
- PhysioNet Sleep-EDF Expanded

Processed nights so far:
- `SC4001E0`
- `SC4011E0`
- `SC4031E0`
- `SC4041E0`

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

### 4. Multi-night replay outcome
Scenario style for each night:
- target = 10 minutes before the end of the labeled sleep interval
- wake window = 30 minutes
- Garmin-constrained poll cadence = 5 minutes

Batch result from `results/evaluation_batch.json`:
- datasets evaluated: **4**
- proposed Garmin-constrained exact match to oracle snapped-to-5-minute cadence: **4 / 4**
- exact match rate: **1.0**

Per-night proposed trigger results:
- `SC4001E0`: trigger 831, stage `Sleep stage R`
- `SC4011E0`: trigger 814, stage `Sleep stage 2`
- `SC4031E0`: trigger 812, stage `Sleep stage 2`
- `SC4041E0`: trigger 926, stage `Sleep stage 2`

Interpretation:
- the revised Garmin-constrained rule matched the earliest reachable good trigger in all four replayed nights under the 5-minute polling assumption used here.

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

### UI changes
Monitoring screen now reports:
- HR
- Stress
- Body Battery

instead of:
- HR
- HRV
- respiration

## Verification performed
- app compiles successfully with `monkeyc`
- replay harness executes successfully on four public real sleep nights
- batch evaluation JSON generated successfully
- per-night plots generated successfully
- revised rule matches oracle snapped to 5-minute cadence on 4/4 current nights

## Blockers / incomplete
1. The replay harness still uses proxy features derived from PSG channels, not raw Garmin watch exports.
2. Simulator launch on this host currently fails with:
   - `libsoup-ERROR: libsoup2 symbols detected. Using libsoup2 and libsoup3 in the same process is not supported.`
3. The app has not yet been validated on a physical Venu 2 with observed live sensor-history values.
4. More nights should be added before declaring the algorithm robust.
5. Motion/accelerometer-informed logic is not yet wired into the actual app runtime.

## Next recommended steps
1. Add a larger batch of Sleep-EDF nights and look for failure cases.
2. Add scenario diversity (cases with weaker late-window light sleep and forced fallback-to-target behavior).
3. Resolve simulator runtime issue or shift to direct watch-side validation.
4. Add optional foreground motion sensing if Venu 2 runtime testing supports it.
