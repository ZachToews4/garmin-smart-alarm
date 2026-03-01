# Smart Alarm — Garmin Venu 2

A smart sleep-alarm watchApp for the Garmin Venu 2 that wakes you during light sleep within a configurable window before your target wake time.

---

## How It Works

1. **Set your target wake time** (e.g. 7:00 AM).
2. **Set your wake window** (10, 20, 30, 45, or 60 min before the target).
3. Tap **Start Alarm** and wear your watch to sleep.
4. During the window the app monitors:
   - **Heart rate** via `Toybox.Sensor` — sleep HR typically 40–70 bpm.
   - **Accelerometer** via raw accel data — low variance = low movement.
5. When both conditions are met → **vibration alarm** fires immediately.
6. If no light sleep is detected before your target time → **alarm fires at the target time anyway**.
7. After the alarm, the screen shows the time it fired. Press **Back** to dismiss.

---

## Project Structure

```
garmin-smart-alarm/
├── manifest.xml                # App manifest (targets venu2)
├── monkey.jungle               # Build script
├── README.md                   # This file
├── resources/
│   ├── drawables/
│   │   └── drawables.xml       # Launcher icon reference
│   ├── layouts/
│   │   └── layout.xml          # Placeholder (UI drawn programmatically)
│   ├── menus/
│   │   └── menus.xml           # Menu item definitions
│   └── strings/
│       └── strings.xml         # App strings
└── source/
    ├── SmartAlarmApp.mc        # Application entry point
    ├── AlarmManager.mc         # Singleton: sensor logic, timers, alarm state
    ├── MainView.mc             # Primary UI (idle / monitoring / fired states)
    ├── MainDelegate.mc         # Input handler for main view
    ├── MainMenuDelegate.mc     # Menu: set time, set window, start/cancel
    ├── TimePickerView.mc       # Hour+minute picker using NumberPickerView
    └── WindowPickerView.mc     # Wake-window picker (10/20/30/45/60 min)
```

---

## Requirements

- **Garmin Connect IQ SDK** 4.x or later ([developer.garmin.com/connect-iq](https://developer.garmin.com/connect-iq/sdk/))
- **VS Code** + [Monkey C extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c) **OR** command-line SDK tools
- A **Garmin Venu 2** (or the Venu 2 simulator)

### Launcher Icon

The manifest references `resources/drawables/launcher_icon.png`.  
Add a **70×70 px** PNG at that path before building (required by the SDK).  
A simple placeholder square will satisfy the build.

---

## Build & Sideload Instructions

### Option A — VS Code (recommended)

1. Install the **Monkey C** VS Code extension.
2. Open the `garmin-smart-alarm/` folder.
3. Set your developer key: `Ctrl+Shift+P` → **Monkey C: Generate Developer Key**.
4. Press `F5` to build and launch the **Venu 2 simulator**.
5. To sideload to a real device:
   - `Ctrl+Shift+P` → **Monkey C: Build for Device**
   - Copy the generated `.prg` file (in `bin/`) to `GARMIN/APPS/` on your Venu 2.
   - Eject the watch — the app appears in the app list.

### Option B — Command Line

```bash
# 1. Set SDK path (adjust to your install location)
export CIQ_HOME=~/garmin/connectiq-sdk

# 2. Generate a developer key (one-time)
openssl genrsa -out developer_key 4096
openssl rsa -in developer_key -pubout -out developer_key.pub

# 3. Build
$CIQ_HOME/bin/monkeyc \
  -f monkey.jungle \
  -o bin/smart-alarm.prg \
  -y developer_key \
  -d venu2

# 4. Run in simulator
$CIQ_HOME/bin/connectiq &          # start simulator
$CIQ_HOME/bin/monkeydo bin/smart-alarm.prg venu2

# 5. Sideload to real watch
# Copy bin/smart-alarm.prg → GARMIN/APPS/ on the Venu 2 MTP mount
```

---

## Tuning Sleep Detection

The heuristics are in `AlarmManager.mc` — adjust these constants to taste:

| Constant | Default | Meaning |
|---|---|---|
| `ACCEL_VAR_THRESH` | `50.0` (mg²) | Max accel variance to count as "low movement" |
| `HR_SLEEP_MIN` | `40` bpm | Lower bound of sleep HR range |
| `HR_SLEEP_MAX` | `70` bpm | Upper bound of sleep HR range |
| `POLL_INTERVAL_MS` | `30000` ms | How often sleep state is evaluated (30 s) |
| `VIBE_REPEATS` | `8` | Vibration pulses on alarm |

---

## Known Limitations

- **Sensor availability:** Garmin's CIQ API exposes HR and raw accelerometer, but the exact data rate is firmware-dependent. The app gracefully handles missing samples.
- **Background restrictions:** `watchApp` type apps keep the screen on and run fully — this is intentional for a sleep app, but will consume more battery than a `watchFace` or `background` app.
- **No sound:** Vibration only, by design. Venu 2 supports `Attention.vibrate()`.
- **Launcher icon:** You must supply your own 70×70 px PNG (`resources/drawables/launcher_icon.png`).

---

## License

MIT — do whatever you want with it.
