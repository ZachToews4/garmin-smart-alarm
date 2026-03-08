# Smart Alarm — Developer Notes

Lessons learned the hard way so future-me doesn't repeat them.

---

## Simulator (Garmin Connect IQ)

### Starting the simulator

The simulator must already be running before `monkeydo` is called.
It was started once at setup and persists as a background process.
Check if it's running: `ps -ef | grep simulator | grep -v grep`

### Build + Deploy

```bash
# Build
/home/zach/garmin/sdk/bin/monkeyc \
  -f monkey.jungle \
  -o bin/smart-alarm.prg \
  -y /home/zach/garmin/developer_key.der \
  -d venu2

# Deploy to running simulator
/home/zach/garmin/sdk/bin/monkeydo bin/smart-alarm.prg venu2
```

`monkeydo` exits as soon as the PRG is pushed. The simulator keeps running.
`monkeydo` captures `System.println()` output — check the process log after.

### Screenshots (headless)

The simulator runs on virtual display `:99`.

```bash
# Find the window ID (do this once)
DISPLAY=:99 xdotool search --name "Venu"
# → e.g. 2097166

# Capture
DISPLAY=:99 import -window 2097166 screenshot.png
```

Window ID stays stable for the lifetime of the simulator process.

### Sending input

**Clicks (touch / tap):**
```bash
DISPLAY=:99 xdotool mousemove --window 2097166 300 400 click 1
```
Coordinates are relative to the full window (including title bar / chrome).
Watch face centre is approximately x=300. Menu items are roughly:
- Item 1: y≈300
- Item 2: y≈440
- Item 3: y≈580

**Keyboard (hardware buttons / back):**
```bash
# Must click first to give the window focus, then send key
DISPLAY=:99 xdotool mousemove --window 2097166 300 400 click 1
sleep 0.5
DISPLAY=:99 xdotool key --window 2097166 Escape   # = Back button
DISPLAY=:99 xdotool key --window 2097166 Return    # = Select / Enter
DISPLAY=:99 xdotool key --window 2097166 Down      # = scroll down
```

**Important:** `xdotool windowactivate` fails on this WM ("not support
_NET_ACTIVE_WINDOW"). The workaround is a `click 1` first, then the key.

**Scrolling menus:** Swipe gestures (mousedown → mousemove → mouseup)
don't scroll Menu2 reliably. The simulator seems to eat the drag events.
**Solution:** Put the most important menu items first (top of the list)
so they're always visible without scrolling.

### Reading simulator console output

`System.println()` in Monkey C goes to the simulator's internal console —
NOT to monkeydo's stdout. But `monkeydo` captures it when run via exec:

```bash
/home/zach/garmin/sdk/bin/monkeydo bin/smart-alarm.prg venu2
# then: process(action=log, sessionId=<id>)
```

The output shows up in the process log after deploy.
Historical output is also in `/tmp/monkeydo_out.txt` from earlier runs.

### Crash screen

A **blue triangle** in the middle of the watch face = runtime crash (CIQ
unhandled exception). It's not always obvious from the outside what crashed.
Narrow it down by stripping code back to a minimal reproducer.

---

## Monkey C / CIQ Gotchas

### `(:background)` classes cannot import foreground-only modules

Any file or class annotated `(:background)` runs in the background
service context. Importing foreground-only Toybox modules there causes
an **immediate load-time crash** (blue triangle, no error message shown).

**Forbidden in `(:background)` context:**
- `import Toybox.Attention`
- `import Toybox.WatchUi`
- Any UI / sensor foreground API

`SmartAlarmApp` is `(:background)` — do NOT add foreground imports to it.
`AlarmBackground` is also `(:background)` — same rule.
`AlarmManager` is foreground-only — Attention imports are fine there.

### `Attention.vibrate()` — max 8 VibeProfile segments

```monkey-c
// WRONG — 15 segments when VIBE_REPEATS=8, crashes with "Too Many Arguments"
var pattern = new[VIBE_REPEATS * 2 - 1];

// RIGHT — clamp to 8
var patternSize = VIBE_REPEATS * 2 - 1;
if (patternSize > 8) { patternSize = 8; }
var pattern = new[patternSize];
```

Each `VibeProfile(duty, durationMs)`:
- duty: 0–100 (0 = off, 100 = full power)
- durationMs: milliseconds for this segment

### `SleepDetector` must be tagged `(:background)`

`AlarmBackground.onTemporalEvent()` instantiates `SleepDetector`. If
`SleepDetector` is not tagged `(:background)`, the background service
crashes on first temporal event with an access error.

### Background service timing

`Background.registerForTemporalEvent(new Time.Duration(60))` — minimum
interval is 1 minute. The service wakes, runs `onTemporalEvent()`, and
exits. It does NOT run continuously.

### Storage keys (defined in Constants.mc)

```
KEY_RUNNING        — Boolean: alarm is active
KEY_WAKE_HOUR      — Number: wake target hour
KEY_WAKE_MIN       — Number: wake target minute
KEY_WINDOW         — Number: window in minutes
KEY_SNOOZE_MINS    — Number: snooze duration
KEY_SLEEP_ONSET    — Number: epoch of detected sleep onset
KEY_ONSET_COUNT    — Number: consecutive onset readings
KEY_SNOOZE_MODE    — Boolean: currently snoozing
KEY_SNOOZE_TARGET  — Number: snooze target in minutes-since-midnight
```

### Timer limits

CIQ has a maximum number of concurrent `Timer.Timer` objects. Keep timer
count low. `AlarmManager` uses one display-refresh timer (`_displayTimer`)
and that's it — don't add more without removing one first.

### `WatchUi.requestUpdate()` from wrong context

Calling `WatchUi.requestUpdate()` from `onStart()` (before the view stack
is initialized) or from a background context crashes the app. Only call it
after the view is pushed.

---

## Project Structure

```
source/
  SmartAlarmApp.mc       — App entry point (:background) — NO foreground imports
  AlarmManager.mc        — Singleton, foreground alarm state + logic
  AlarmBackground.mc     — (:background) temporal event handler
  SleepDetector.mc       — (:background) sleep onset detection
  MainView.mc            — Primary watch face view
  MainDelegate.mc        — Input handler, opens menu
  MainMenuDelegate.mc    — Menu item handler
  TimePickerView.mc      — Hour/minute picker
  TimePickerDelegate.mc
  WindowPickerView.mc    — Window duration picker
  WindowPickerDelegate.mc
  SnoozePickerView.mc    — Snooze duration picker
  SnoozePickerDelegate.mc
  Constants.mc           — Storage keys, vibe constants
```

---

## Key paths

- SDK: `/home/zach/garmin/sdk/`
- Developer key: `/home/zach/garmin/developer_key.der`
- Simulator virtual display: `:99`
- Simulator window name: "Venu" (for xdotool search)
