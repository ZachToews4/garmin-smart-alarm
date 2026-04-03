// Constants.mc
// Single source of truth for all shared constants.
//
// ⚠️  RULE: Do NOT use module blocks here. Module-scoped constants (even
//     numeric ones inside :background modules) crash the foreground binary
//     at load time if any foreground method body references them. Use plain
//     top-level const declarations only — they are safe in all contexts.

// ── Storage keys ──────────────────────────────────────────────────────────────
const KEY_TARGET          = "targetMinutes";
const KEY_WINDOW          = "windowMinutes";
const KEY_SNOOZE          = "snoozeMinutes";
const KEY_RUNNING         = "isRunning";
const KEY_START_MINS      = "startMinutes";
const KEY_SLEEP_ONSET     = "sleepOnsetMins";
const KEY_ONSET_COUNT     = "onsetConfirmCount";
const KEY_SNOOZE_MODE     = "snoozeMode";
const KEY_SNOOZE_TARGET   = "snoozeTarget";
const KEY_BG_FIRED        = "bgFired";
const KEY_BG_FIRED_MINS   = "bgFiredTimeMins";
const KEY_BG_FIRED_REASON = "bgFiredReason";

// ── Sleep detection thresholds ────────────────────────────────────────────────
// Garmin-plausible signal plan for Venu 2:
// - Background path: rely on SensorHistory values known to exist broadly on-device
//   (heart rate, stress, Body Battery)
// - Foreground path can later add live motion sensing via Toybox.Sensor if desired
// These thresholds are intentionally conservative and favor target-time fallback
// over false early wakes.
const HR_SLEEP_MIN                 = 45;
const HR_SLEEP_MAX                 = 72;
const STRESS_SLEEP_MAX             = 35;
const STRESS_LIGHT_MAX             = 22;
const BODY_BATTERY_RECOVERED_MIN   = 25;
const ONSET_CONFIRM_BG             = 2;
const PRE_MONITOR_DELAY_MIN        = 30;
const MIN_WINDOW_TRIGGER_OFFSET    = 5;

// ── Signal sentinels ──────────────────────────────────────────────────────────
const SIGNAL_UNAVAILABLE_INT = -1;

// ── Vibration pattern ─────────────────────────────────────────────────────────
const VIBE_DUTY         = 100;
const VIBE_ON_MS        = 500;
const VIBE_OFF_MS       = 300;
const VIBE_MAX_SEGMENTS = 8;   // Attention.vibrate() accepts at most 8 VibeProfiles per call
const VIBE_REPEATS      = 8;   // Requested pulses — truncated as needed to meet the segment cap
