// AlarmBackground.mc
// Sole alarm detection engine — runs every ~60 seconds via temporal event.
// Handles deadline, smart-wake detection, sleep onset tracking, and snooze.
// Uses Constants.mc (Keys/Thresholds/Vibe) and SleepDetector.mc.
//
// All state is persisted via Application.Storage so it survives across
// temporal event wake-ups with no in-memory continuity.

import Toybox.Application;
import Toybox.Attention;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

(:background)
class AlarmBackground extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    // ── Main entry point ──────────────────────────────────────────────────────

    function onTemporalEvent() as Void {
        var running = Application.Storage.getValue(KEY_RUNNING);
        if (running == null || !(running as Boolean)) { return; }

        var nowMins    = _nowMinutes();
        var isSnooze   = _getBool(KEY_SNOOZE_MODE);

        // Target time: snooze override or main alarm target
        var targetKey  = isSnooze ? KEY_SNOOZE_TARGET : KEY_TARGET;
        var targetVal  = Application.Storage.getValue(targetKey);
        if (targetVal == null) { _cancel(); return; }
        var target = targetVal as Number;

        var windowVal  = Application.Storage.getValue(KEY_WINDOW);
        var window     = (windowVal != null) ? windowVal as Number : 20;

        // Minutes until target (wraps correctly across midnight)
        var dist = (target - nowMins + 1440) % 1440;

        // ── Deadline ──────────────────────────────────────────────────────────
        // Fire at target time, 1 min early (background fires slightly early),
        // or 1 min late (event skipped + wrap-around). All within tolerance.
        if (dist <= 1 || dist >= 1439) {
            _fireAlarm(isSnooze ? "Snooze" : "Target time", isSnooze);
            return;
        }

        // ── Outside wake window ───────────────────────────────────────────────
        if (dist > window) {
            if (!isSnooze) { _updateOnsetTracking(nowMins); }
            _reschedule();
            return;
        }

        // ── Inside wake window — check pre-monitor delay ───────────────────────
        if (!isSnooze) {
            var startVal  = Application.Storage.getValue(KEY_START_MINS);
            var startMins = (startVal != null) ? startVal as Number : nowMins;
            var elapsed   = (nowMins - startMins + 1440) % 1440;
            var halfWindow = window / 2;
            var delay = (Thresholds.PRE_MONITOR_DELAY_MIN < halfWindow)
                ? Thresholds.PRE_MONITOR_DELAY_MIN
                : halfWindow;
            if (elapsed < delay) {
                _reschedule();
                return;
            }
        }

        // ── Smart wake: check biometrics ──────────────────────────────────────
        var onsetMins = _getInt(KEY_SLEEP_ONSET);
        if (!isSnooze) { _updateOnsetTracking(nowMins); }

        if (SleepDetector.isLightSleep(onsetMins, nowMins, isSnooze)) {
            _fireAlarm("Smart wake", isSnooze);
        } else {
            _reschedule();
        }
    }

    // ── Sleep onset tracking ──────────────────────────────────────────────────
    // Requires ONSET_CONFIRM_BG consecutive background wake-ups showing sleep
    // biometrics before onset is confirmed (prevents single-sample false onset).

    private function _updateOnsetTracking(nowMins as Number) as Void {
        if (_getInt(KEY_SLEEP_ONSET) >= 0) { return; }  // already confirmed

        var hr   = SleepDetector.readHR();
        var hrv  = SleepDetector.readHRV();
        var resp = SleepDetector.readResp();

        var signals = 0; var sleepSigs = 0;
        if (hr >= 0) {
            signals++;
            if (hr >= Thresholds.HR_SLEEP_MIN && hr <= Thresholds.HR_SLEEP_MAX) { sleepSigs++; }
        }
        if (hrv >= 0) {
            signals++;
            if (hrv >= Thresholds.HRV_LIGHT_MIN && hrv <= Thresholds.HRV_LIGHT_MAX) { sleepSigs++; }
        }
        if (resp >= 0.0f) {
            signals++;
            if (resp >= Thresholds.RESP_SLEEP_MIN && resp <= Thresholds.RESP_SLEEP_MAX) { sleepSigs++; }
        }

        if (signals == 0) { return; }

        if (sleepSigs * 2 >= signals) {
            // Looks like sleep — increment confirmation counter
            var count = _getInt(KEY_ONSET_COUNT);
            var n     = (count >= 0 ? count : 0) + 1;
            if (n >= Thresholds.ONSET_CONFIRM_BG) {
                Application.Storage.setValue(KEY_SLEEP_ONSET, nowMins);
                Application.Storage.deleteValue(KEY_ONSET_COUNT);
            } else {
                Application.Storage.setValue(KEY_ONSET_COUNT, n);
            }
        } else {
            // Doesn't look like sleep — reset counter
            Application.Storage.deleteValue(KEY_ONSET_COUNT);
        }
    }

    // ── Alarm firing ──────────────────────────────────────────────────────────

    private function _fireAlarm(reason as String, isSnooze as Boolean) as Void {
        // Clear all runtime state
        Application.Storage.deleteValue(KEY_RUNNING);
        Application.Storage.deleteValue(KEY_SLEEP_ONSET);
        Application.Storage.deleteValue(KEY_ONSET_COUNT);
        if (isSnooze) {
            Application.Storage.deleteValue(KEY_SNOOZE_MODE);
            Application.Storage.deleteValue(KEY_SNOOZE_TARGET);
        }

        // Store fired state for foreground to display when user opens the app
        Application.Storage.setValue(KEY_BG_FIRED, true);
        Application.Storage.setValue(KEY_BG_FIRED_MINS, _nowMinutes());
        Application.Storage.setValue(KEY_BG_FIRED_REASON, reason);

        // Vibrate
        if (Attention has :vibrate) {
            var patternSize = Vibe.REPEATS * 2 - 1;
            var pattern = new[patternSize] as Array<Attention.VibeProfile>;
            for (var i = 0; i < patternSize; i++) {
                pattern[i] = new Attention.VibeProfile(
                    i % 2 == 0 ? Vibe.DUTY : 0,
                    i % 2 == 0 ? Vibe.ON_MS : Vibe.OFF_MS
                );
            }
            Attention.vibrate(pattern);
        }
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }

        Background.deleteTemporalEvent();
    }

    // ── Cancel background (called when Storage state is corrupted) ────────────
    // Clears all runtime keys so the app starts clean on next open.

    private function _cancel() as Void {
        Application.Storage.deleteValue(KEY_RUNNING);
        Application.Storage.deleteValue(KEY_SNOOZE_MODE);
        Application.Storage.deleteValue(KEY_SNOOZE_TARGET);
        Application.Storage.deleteValue(KEY_SLEEP_ONSET);
        Application.Storage.deleteValue(KEY_ONSET_COUNT);
        Background.deleteTemporalEvent();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function _reschedule() as Void {
        Background.registerForTemporalEvent(new Time.Duration(60));
    }

    private function _nowMinutes() as Number {
        var t = System.getClockTime();
        return t.hour * 60 + t.min;
    }

    // Read a Boolean from Storage, default false.
    private function _getBool(key as String) as Boolean {
        var v = Application.Storage.getValue(key);
        return v != null && (v as Boolean);
    }

    // Read a Number from Storage, default -1.
    private function _getInt(key as String) as Number {
        var v = Application.Storage.getValue(key);
        return (v != null) ? v as Number : -1;
    }
}
