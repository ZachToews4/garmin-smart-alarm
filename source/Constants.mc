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
const HR_SLEEP_MIN          = 40;
const HR_SLEEP_MAX          = 70;
const HRV_LIGHT_MIN         = 20;
const HRV_LIGHT_MAX         = 75;
const HRV_DEEP_THRESH       = 80;
const RESP_SLEEP_MIN        = 8.0f;
const RESP_SLEEP_MAX        = 16.0f;
const CYCLE_MIN             = 90;
const CYCLE_WINDOW_MIN      = 15;
const ONSET_CONFIRM_BG      = 3;
const PRE_MONITOR_DELAY_MIN = 30;

// ── Vibration pattern ─────────────────────────────────────────────────────────
const VIBE_DUTY    = 100;
const VIBE_ON_MS   = 500;
const VIBE_OFF_MS  = 300;
const VIBE_REPEATS = 8;
