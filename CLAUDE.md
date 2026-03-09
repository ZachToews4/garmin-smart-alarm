# Smart Alarm — Claude Context

Garmin Connect IQ watchApp for the Venu 2. Smart alarm that monitors sleep
biometrics and fires during light sleep within a configurable wake window.

---

## Build & Run

```bash
# Build
/home/zach/garmin/sdk/bin/monkeyc \
  -f monkey.jungle \
  -o bin/smart-alarm.prg \
  -y /home/zach/garmin/developer_key.der \
  -d venu2

# Deploy to simulator (simulator must already be running)
/home/zach/garmin/sdk/bin/monkeydo bin/smart-alarm.prg venu2

# Deploy to physical watch (connect via USB first)
mkdir -p /tmp/garmin_mnt
jmtpfs /tmp/garmin_mnt
cp bin/smart-alarm.prg "/tmp/garmin_mnt/Internal Storage/GARMIN/APPS/"
fusermount -u /tmp/garmin_mnt
```

**Key paths:**
- SDK: `/home/zach/garmin/sdk/`
- Developer key: `/home/zach/garmin/developer_key.der`
- Target device: `venu2` (Garmin Venu 2, CIQ 4.1)

---

## Project Structure

```
source/
  SmartAlarmApp.mc        App entry point — (:background) annotated
  AlarmManager.mc         Foreground singleton — alarm state machine
  AlarmBackground.mc      (:background) — temporal event handler, fires alarm
  SleepDetector.mc        (:background) — biometric sleep stage inference
  MainView.mc             Idle/monitoring watch face
  MainDelegate.mc         Touch input, opens menu
  MainMenuDelegate.mc     Menu item handler
  TimePickerView.mc       Wake time hour/minute picker
  TimePickerDelegate.mc
  WindowPickerView.mc     Window duration picker
  WindowPickerDelegate.mc
  SnoozePickerView.mc     Snooze duration picker
  SnoozePickerDelegate.mc
  Constants.mc            All shared constants and storage keys
```

---

## Architecture

The app uses Garmin's **background service** pattern:

- **Foreground** (`AlarmManager`, views, delegates): user interaction,
  alarm configuration, displaying state, vibrating/alerting when fired.
- **Background** (`AlarmBackground`, `SleepDetector`): wakes every 60 s
  via `Background.registerForTemporalEvent()`, reads SensorHistory, decides
  whether to fire the alarm, writes result to `Application.Storage`.

The background service **does not run continuously** — it wakes, runs
`onTemporalEvent()`, and exits. All persistent state lives in `Storage`.

### State flow

```
Idle → [Start Alarm] → Monitoring (background polling every 60 s)
     → [light sleep detected in window] → Alarm Fired (vibrate + screen)
     → [tap] → Snooze (re-registers background, shorter target)
     → [tap] or [back] → Idle
```

### Storage keys (all defined in Constants.mc)

| Key | Type | Purpose |
|-----|------|---------|
| `KEY_RUNNING` | Boolean | Alarm is active |
| `KEY_TARGET` | Number | Wake target (minutes-of-day) |
| `KEY_WINDOW` | Number | Window width (minutes) |
| `KEY_SNOOZE` | Number | Snooze duration (minutes) |
| `KEY_START_MINS` | Number | When monitoring began |
| `KEY_SLEEP_ONSET` | Number | Confirmed sleep onset (minutes-of-day) |
| `KEY_ONSET_COUNT` | Number | Consecutive onset readings so far |
| `KEY_SNOOZE_MODE` | Boolean | Currently snoozing |
| `KEY_SNOOZE_TARGET` | Number | Snooze wake target (minutes-of-day) |
| `KEY_BG_FIRED` | Boolean | Background fired alarm (foreground polls) |
| `KEY_BG_FIRED_MINS` | Number | Time background fired (minutes-of-day) |
| `KEY_BG_FIRED_REASON` | String | Reason string for fired screen |

---

## Sleep Detection (SleepDetector.mc)

Reads the last 2 minutes of `SensorHistory` each background wake:

| Signal | "Light sleep" range |
|--------|-------------------|
| Heart rate | 40–70 bpm |
| HRV | 20–75 ms (>80 ms = deep sleep veto) |
| Respiration | 8–16 breaths/min |

Scoring: if ≥50% of available signals agree → light sleep (near a 90-min
cycle boundary); ≥75% required mid-cycle. Requires 3 consecutive
confirmations (`ONSET_CONFIRM_BG`) before locking in sleep onset.
A 30-minute pre-monitoring delay (`PRE_MONITOR_DELAY_MIN`) prevents
early false positives.

**Known gap:** No movement/accelerometer data currently used, despite
Venu 2 supporting CIQ 4.x accelerometer access. Adding motion gating
(skip fire if accel deviates significantly from 1g) is a planned improvement.

---

## Critical Rules — Read Before Touching Anything

### 1. `(:background)` annotation rules

Only `SmartAlarmApp` and `AlarmBackground` are annotated `(:background)`.
**Do not annotate anything else.** `SleepDetector` is NOT annotated — it
is reachable from background code and gets included automatically.

`(:background)` symbols are excluded from the foreground binary. A foreground
method body that references a `(:background)` symbol crashes at load time,
even if that code path is never called.

### 2. No foreground-only imports in `(:background)` classes

`SmartAlarmApp` and `AlarmBackground` must never import foreground-only
modules. This causes an **immediate blue-triangle crash at load time**
with no useful error message.

**Forbidden in `SmartAlarmApp.mc` and `AlarmBackground.mc`:**
```monkey-c
import Toybox.Attention   // ❌ foreground only
import Toybox.WatchUi     // ❌ foreground only
```

`AlarmManager.mc` is foreground-only — these imports are fine there.

### 3. Constants.mc — no module blocks

Do NOT wrap constants in `module` blocks. Module-scoped constants in a
file that's compiled into both foreground and background binaries cause
load-time crashes. All constants must be flat top-level `const` declarations.

```monkey-c
// ❌ Wrong
module MyModule {
    const FOO = 1;
}

// ✅ Right
const FOO = 1;
```

### 4. `Attention.vibrate()` — max 8 VibeProfiles

Always clamp the pattern array to 8 elements or fewer:
```monkey-c
var patternSize = VIBE_REPEATS * 2 - 1;
if (patternSize > VIBE_MAX_SEGMENTS) { patternSize = VIBE_MAX_SEGMENTS; }
var pattern = new[patternSize] as Array<Attention.VibeProfile>;
```

### 5. `WatchUi.requestUpdate()` — foreground only, after view push

Never call from `onStart()` or any background context. Only call after
the view stack is initialized (i.e., from a timer callback, delegate, or
view method).

### 6. Timer count

CIQ enforces a maximum concurrent timer limit. `AlarmManager` uses one
`_displayTimer`. Don't add timers without removing one first.

---

## Simulator Workflow (headless, display :99)

See `DEVNOTES.md` for the full reference. Quick summary:

```bash
# Screenshot
DISPLAY=:99 xdotool search --name "Venu"   # get window ID once
DISPLAY=:99 import -window <id> out.png

# Tap
DISPLAY=:99 xdotool mousemove --window <id> 300 400 click 1

# Back button — MUST click first to give focus, then send key
DISPLAY=:99 xdotool mousemove --window <id> 300 400 click 1
sleep 0.5
DISPLAY=:99 xdotool key --window <id> Escape

# Menu item Y coordinates (approx)
# Item 1: y≈300  Item 2: y≈440  Item 3: y≈580
```

**Menu scroll doesn't work reliably via swipe.** Keep the highest-priority
items at the top of every menu.

**Blue triangle** = runtime crash. Strip back to a minimal reproducer to isolate.

`System.println()` output is captured by `monkeydo` in the process log —
use it liberally for debugging, remove before committing.

---

## Planned / Known Issues

- **Accelerometer integration** — Venu 2 supports CIQ 4.x motion data.
  Adding a motion check in `SleepDetector` (skip fire if significant movement
  at background wake time) would improve accuracy. See discussion in commit
  history.
- **AM display bug** — Wake time shows "6:30 A" with a blank box instead of
  "6:30 AM" (font/layout issue in `MainView`).
