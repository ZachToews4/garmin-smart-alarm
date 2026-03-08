// SleepDetector.mc
// Reads biometric data from SensorHistory and determines sleep stage.
// Annotated (:background) so it can be used by both AlarmBackground and
// AlarmManager (foreground display refresh).
//
// Design: pure SensorHistory reads — no live sensor callbacks, no in-memory
// state. Safe to call from any context.

import Toybox.Lang;
import Toybox.SensorHistory;

(:background)
class SleepDetector {

    // ── Biometric readers ─────────────────────────────────────────────────────
    // Each returns the most recent value from the last 2 minutes of SensorHistory,
    // or a sentinel (-1 / -1.0f) if data is unavailable.

    static function readHR() as Number {
        if (!(SensorHistory has :getHeartRateHistory)) { return -1; }
        var iter = SensorHistory.getHeartRateHistory(
            {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
        if (iter == null) { return -1; }
        var s = iter.next();
        if (s == null || s.data == null) { return -1; }
        return s.data as Number;
    }

    static function readHRV() as Number {
        if (!(SensorHistory has :getHeartRateVariabilityHistory)) { return -1; }
        var iter = SensorHistory.getHeartRateVariabilityHistory(
            {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
        if (iter == null) { return -1; }
        var s = iter.next();
        if (s == null || s.data == null) { return -1; }
        if (s.data instanceof Float) { return (s.data as Float).toNumber(); }
        return s.data as Number;
    }

    static function readResp() as Float {
        if (!(SensorHistory has :getRespirationRateHistory)) { return -1.0f; }
        var iter = SensorHistory.getRespirationRateHistory(
            {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
        if (iter == null) { return -1.0f; }
        var s = iter.next();
        if (s == null || s.data == null) { return -1.0f; }
        if (s.data instanceof Float) { return s.data as Float; }
        return (s.data as Number).toFloat();
    }

    // ── Sleep stage inference ─────────────────────────────────────────────────
    // Returns true if available biometrics suggest the user is in light sleep.
    //
    // sleepOnsetMins: confirmed sleep onset time (minutes-of-day), or -1 if
    //   not yet detected. Used to calculate 90-min cycle position.
    // nowMins: current time in minutes-of-day.
    // snoozeMode: if true, skip cycle window constraint (snooze doesn't use it).

    static function isLightSleep(
        sleepOnsetMins as Number,
        nowMins        as Number,
        snoozeMode     as Boolean) as Boolean {

        var hr   = readHR();
        var hrv  = readHRV();
        var resp = readResp();

        // Hard gate: strong HRV evidence of deep sleep → hold off
        if (hrv >= 0 && hrv > Thresholds.HRV_DEEP_THRESH) { return false; }

        // Score available signals
        var signals   = 0;
        var confirmed = 0;

        if (hr >= 0) {
            signals++;
            if (hr >= Thresholds.HR_SLEEP_MIN && hr <= Thresholds.HR_SLEEP_MAX) {
                confirmed++;
            }
        }
        if (hrv >= 0) {
            signals++;
            if (hrv >= Thresholds.HRV_LIGHT_MIN && hrv <= Thresholds.HRV_LIGHT_MAX) {
                confirmed++;
            }
        }
        if (resp >= 0.0f) {
            signals++;
            if (resp >= Thresholds.RESP_SLEEP_MIN && resp <= Thresholds.RESP_SLEEP_MAX) {
                confirmed++;
            }
        }

        // No data available → don't false-fire
        if (signals == 0) { return false; }

        var inWindow = snoozeMode ? true : _inCycleWindow(sleepOnsetMins, nowMins);

        if (inWindow) {
            // Near a 90-min cycle boundary: majority (≥ 50 %) must agree
            return confirmed * 2 >= signals;
        } else {
            // Mid-cycle (likely deep sleep): require strong majority (≥ 75 %)
            return confirmed * 4 >= signals * 3;
        }
    }

    // ── Cycle window ──────────────────────────────────────────────────────────
    // Returns true when we're near a 90-minute cycle boundary (±CYCLE_WINDOW_MIN).
    // Light sleep naturally occurs at these transitions.

    private static function _inCycleWindow(
        sleepOnsetMins as Number,
        nowMins        as Number) as Boolean {

        if (sleepOnsetMins < 0) { return true; }  // onset unknown → no constraint

        var elapsed  = (nowMins - sleepOnsetMins + 1440) % 1440;
        var cyclePos = elapsed % Thresholds.CYCLE_MIN;

        return cyclePos <= Thresholds.CYCLE_WINDOW_MIN ||
               cyclePos >= (Thresholds.CYCLE_MIN - Thresholds.CYCLE_WINDOW_MIN);
    }
}
