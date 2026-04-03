// SleepDetector.mc
// Reads wearable-accessible data from SensorHistory and decides whether the
// current background wake looks like a reasonable smart-alarm trigger point.
//
// Design goal: stay compatible with Garmin Venu 2 constraints instead of
// relying on signals that may not exist in background history.

import Toybox.Lang;
import Toybox.SensorHistory;

(:background)
class SleepDetector {

    // ── SensorHistory readers ────────────────────────────────────────────────

    static function readHR() as Number {
        if (!(SensorHistory has :getHeartRateHistory)) { return SIGNAL_UNAVAILABLE_INT; }
        var iter = SensorHistory.getHeartRateHistory(
            {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
        if (iter == null) { return SIGNAL_UNAVAILABLE_INT; }
        var s = iter.next();
        if (s == null || s.data == null) { return SIGNAL_UNAVAILABLE_INT; }
        return s.data as Number;
    }

    static function readStress() as Number {
        if (!(SensorHistory has :getStressHistory)) { return SIGNAL_UNAVAILABLE_INT; }
        var iter = SensorHistory.getStressHistory(
            {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
        if (iter == null) { return SIGNAL_UNAVAILABLE_INT; }
        var s = iter.next();
        if (s == null || s.data == null) { return SIGNAL_UNAVAILABLE_INT; }
        return s.data as Number;
    }

    static function readBodyBattery() as Number {
        if (!(SensorHistory has :getBodyBatteryHistory)) { return SIGNAL_UNAVAILABLE_INT; }
        var iter = SensorHistory.getBodyBatteryHistory(
            {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
        if (iter == null) { return SIGNAL_UNAVAILABLE_INT; }
        var s = iter.next();
        if (s == null || s.data == null) { return SIGNAL_UNAVAILABLE_INT; }
        return s.data as Number;
    }

    // ── Sleep-state inference ────────────────────────────────────────────────

    static function looksAsleep() as Boolean {
        var hr     = readHR();
        var stress = readStress();
        var body   = readBodyBattery();

        var signals = 0;
        var asleepSignals = 0;

        if (hr >= 0) {
            signals++;
            if (hr >= HR_SLEEP_MIN && hr <= HR_SLEEP_MAX) {
                asleepSignals++;
            }
        }

        if (stress >= 0) {
            signals++;
            if (stress <= STRESS_SLEEP_MAX) {
                asleepSignals++;
            }
        }

        if (body >= 0) {
            signals++;
            if (body >= BODY_BATTERY_RECOVERED_MIN) {
                asleepSignals++;
            }
        }

        if (signals == 0) { return false; }
        return asleepSignals * 2 >= signals;
    }

    // Light-sleep-ish trigger point for smart wake.
    // We deliberately keep this simple and conservative:
    // - user must still broadly look asleep
    // - low stress is preferred because Garmin exposes it reliably
    // - body battery provides a weak recovery sanity check
    static function shouldTriggerSmartWake(isSnooze as Boolean) as Boolean {
        var hr     = readHR();
        var stress = readStress();
        var body   = readBodyBattery();

        if (!looksAsleep()) { return false; }

        // Snooze mode is intentionally more permissive.
        if (isSnooze) {
            if (stress >= 0 && stress <= STRESS_SLEEP_MAX) { return true; }
            return hr >= 0 && hr <= HR_SLEEP_MAX;
        }

        var favorableSignals = 0;
        var availableSignals = 0;

        if (stress >= 0) {
            availableSignals++;
            if (stress <= STRESS_LIGHT_MAX) { favorableSignals++; }
        }

        if (hr >= 0) {
            availableSignals++;
            if (hr >= HR_SLEEP_MIN && hr <= HR_SLEEP_MAX) { favorableSignals++; }
        }

        if (body >= 0) {
            availableSignals++;
            if (body >= BODY_BATTERY_RECOVERED_MIN) { favorableSignals++; }
        }

        if (availableSignals == 0) { return false; }
        return favorableSignals * 2 >= availableSignals;
    }
}
