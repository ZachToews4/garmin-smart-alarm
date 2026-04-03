# Test Results — Garmin Smart Alarm

## Date
2026-04-03

## Scope
Initial reality-based validation pass for the Garmin smart alarm app using public overnight sleep data and Garmin Connect IQ capability checks.

## Findings

### 1. Current app architecture had a signal mismatch
The app was originally written around:
- heart rate history
- HRV history
- respiration history

But current local CIQ API inspection for this SDK/device path showed reliable `SensorHistory` support for:
- `getHeartRateHistory`
- `getStressHistory`
- `getBodyBatteryHistory`

and **did not show** `getHeartRateVariabilityHistory` or `getRespirationRateHistory` in the API docs path inspected locally via downloaded docs.

Implication: the original background smart-wake logic depended on signals that are unlikely to be available/reliable on the actual Venu 2 path being targeted.

### 2. Public real sleep data pipeline is now working
Dataset source selected first:
- PhysioNet Sleep-EDF Expanded
- Night used so far: `SC4001E0-PSG.edf`
- Hypnogram: `SC4001EC-Hypnogram.edf`

Working local artifacts:
- `data/raw/SC4001E0-PSG.edf`
- `data/raw/SC4001EC-Hypnogram.edf`
- `data/processed/SC4001E0_replay.csv`
- `results/evaluation_SC4001E0.json`
- `results/SC4001E0_replay_plot.png`

### 3. Replay harness works
A replay dataset was built from the EDF + hypnogram files and includes:
- minute-indexed ground-truth sleep stage labels
- derived proxy features for offline experimentation
- scenario evaluation output

### 4. First replay scenario outcome
Scenario:
- sleep interval detected in replay: minute 511 to 870
- target minute: 860
- wake window: 30 min
- Garmin-constrained poll cadence: 5 min

Results from `results/evaluation_SC4001E0.json`:
- baseline current-style trigger: minute 830, stage `Sleep stage R`
- proposed Garmin-constrained trigger: minute 831, stage `Sleep stage R`
- oracle ground truth snapped to 5-minute cadence: minute 831, stage `Sleep stage R`

Interpretation:
- the revised Garmin-constrained decision rule matched the earliest reachable good trigger in this first scenario under 5-minute polling.

## Code changes made

### Changed detection model
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
- replay harness executes successfully on real public sleep data
- evaluation JSON generated successfully
- plot generated successfully

## Blockers / incomplete
1. Only one real overnight record has been processed so far.
2. Simulator launch on this host currently fails with:
   - `libsoup-ERROR: libsoup2 symbols detected. Using libsoup2 and libsoup3 in the same process is not supported.`
3. The app has not yet been validated on a physical Venu 2 with observed sensor history values.
4. Motion/accelerometer-informed logic is not yet wired into the actual app runtime.

## Next recommended steps
1. Add multiple-night evaluation across more Sleep-EDF records.
2. Build a structured pass/fail batch report.
3. Resolve simulator runtime issue or shift to direct watch-side validation.
4. Add optional foreground motion sensing if Venu 2 runtime testing supports it.
