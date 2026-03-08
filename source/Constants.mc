// Constants.mc
// Single source of truth for all shared constants.
// String constants MUST be top-level (not inside module blocks) —
// the CIQ runtime does not support string const inside modules.

// ── Storage keys (top-level — accessible from foreground and background) ──────
const KEY_TARGET        = "targetMinutes";
const KEY_WINDOW        = "windowMinutes";
const KEY_SNOOZE        = "snoozeMinutes";
const KEY_RUNNING       = "isRunning";
const KEY_START_MINS    = "startMinutes";
const KEY_SLEEP_ONSET   = "sleepOnsetMins";
const KEY_ONSET_COUNT   = "onsetConfirmCount";
const KEY_SNOOZE_MODE   = "snoozeMode";
const KEY_SNOOZE_TARGET = "snoozeTarget";
const KEY_BG_FIRED        = "bgFired";
const KEY_BG_FIRED_MINS   = "bgFiredTimeMins";
const KEY_BG_FIRED_REASON = "bgFiredReason";

// ── Sleep detection thresholds (numeric — module const is safe for integers) ──
(:background)
module Thresholds {
    const HR_SLEEP_MIN     = 40;
    const HR_SLEEP_MAX     = 70;
    const HRV_LIGHT_MIN    = 20;
    const HRV_LIGHT_MAX    = 75;
    const HRV_DEEP_THRESH  = 80;
    const RESP_SLEEP_MIN   = 8.0f;
    const RESP_SLEEP_MAX   = 16.0f;
    const CYCLE_MIN        = 90;
    const CYCLE_WINDOW_MIN = 15;
    const ONSET_CONFIRM_BG = 3;
    const PRE_MONITOR_DELAY_MIN = 30;
}

// ── Vibration pattern (numeric — safe in module) ──────────────────────────────
(:background)
module Vibe {
    const DUTY    = 100;
    const ON_MS   = 500;
    const OFF_MS  = 300;
    const REPEATS = 8;
}
