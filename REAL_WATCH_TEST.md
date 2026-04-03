# Real Venu 2 Test Plan

## Current build
Latest local build artifact:
- `bin/smart-alarm.prg`

This build now includes a **Debug Overlay** option intended to help verify what the watch is actually seeing.

## What changed for on-watch validation
The app now exposes, while running:
- HR
- Stress
- Body Battery
- optional **Debug Overlay** with live accelerometer magnitude (`Accel |g|`)

Enable it from the app menu:
- `Debug Overlay: Off` → tap to turn on

## Goal of the first real-watch test
We are not trying to prove overnight smart waking in one jump.
First we want to verify the watch app can actually observe useful signals on-device.

## Test sequence

### Phase 1 — Sideload
1. Connect the Venu 2 to the host over USB.
2. Mount via MTP.
3. Copy `bin/smart-alarm.prg` to `GARMIN/APPS/`.
4. Eject cleanly.
5. Open **Smart Alarm** on the watch.

### Phase 2 — Signal sanity check while awake
On the watch:
1. Open the app.
2. Open the menu.
3. Turn **Debug Overlay** on.
4. Set a wake time a few minutes ahead.
5. Start the alarm.
6. Observe whether the monitoring screen shows:
   - HR updates
   - Stress / Body Battery values
   - Accel `|g|` when debug overlay is enabled

Success condition:
- those values visibly populate and change plausibly while worn / moved.

### Phase 3 — Forced trigger path
While monitoring:
1. Open menu
2. Run **Test Alarm**

Success condition:
- vibration fires
- fired screen appears
- snooze / dismiss behavior works

### Phase 4 — Short real-world behavior check
Do a short nap or couch test:
1. Set wake time 20–30 minutes ahead.
2. Use a 20-minute window.
3. Wear the watch still for a while, then move around lightly, then settle.
4. See whether the app remains stable and whether displayed values track expected changes.

### Phase 5 — Overnight test
After signal sanity is confirmed:
1. Set your actual wake time.
2. Pick a 30-minute window.
3. Wear overnight.
4. In the morning, note:
   - whether it fired
   - approximately when it fired
   - whether it felt early / sensible / target-time fallback

## What I still need from the hardware path
The key unknown is whether Venu 2 actually supplies the expected values in this runtime path:
- SensorHistory heart rate
- SensorHistory stress
- SensorHistory Body Battery
- foreground accelerometer samples for the debug overlay

## Current host limitation
Automatic sideload from this host is blocked until the Venu 2 is connected:
- `jmtpfs` currently reports: `No mtp devices found.`

## Recommended next action when the watch is available
Connect the Venu 2 over USB and I’ll handle the sideload path and final build copy steps.
