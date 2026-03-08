// AlarmBackground.mc
// Background service delegate — wakes every ~60 seconds while alarm is active.
// Checks sleep biometrics via SensorHistory and fires the alarm if conditions
// are met, even when the app is not in the foreground.
//
// ⚠️  Storage key constants MUST match AlarmManager.mc — keep in sync manually!
// ⚠️  No live accelerometer available in background; sleep detection is
//     biometrics-only (HR / HRV / respiration from SensorHistory).

import Toybox.Application;
import Toybox.Attention;
import Toybox.Background;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;

(:background)
class AlarmBackground extends System.ServiceDelegate {

    // ── Storage keys (must match AlarmManager.mc) ─────────────────────────────
    private const KEY_TARGET          = "targetMinutes";
    private const KEY_WINDOW          = "windowMinutes";
    private const KEY_RUNNING         = "isRunning";
    private const KEY_BG_FIRED        = "bgFired";
    private const KEY_BG_FIRED_MINS   = "bgFiredTimeMins";
    private const KEY_BG_FIRED_REASON = "bgFiredReason";

    // ── Sleep detection thresholds (must match AlarmManager.mc) ──────────────
    private const HR_SLEEP_MIN   = 40;
    private const HR_SLEEP_MAX   = 70;
    private const HRV_LIGHT_MIN  = 20;
    private const HRV_LIGHT_MAX  = 75;
    private const RESP_SLEEP_MIN = 8.0f;
    private const RESP_SLEEP_MAX = 16.0f;

    // ── Vibration pattern ─────────────────────────────────────────────────────
    private const VIBE_DUTY    = 100;
    private const VIBE_ON_MS   = 500;
    private const VIBE_OFF_MS  = 300;
    private const VIBE_REPEATS = 8;

    function initialize() {
        ServiceDelegate.initialize();
    }

    // Called every time the temporal event fires.
    function onTemporalEvent() as Void {
        // Bail immediately if alarm is no longer active
        var running = Application.Storage.getValue(KEY_RUNNING);
        if (running == null || !(running as Boolean)) {
            return;
        }

        var targetVal = Application.Storage.getValue(KEY_TARGET);
        if (targetVal == null) { return; }

        var target = targetVal as Number;
        var windowVal = Application.Storage.getValue(KEY_WINDOW);
        var window = (windowVal != null) ? windowVal as Number : 20;

        var nowMins = _nowMinutes();

        // Minutes until target time (wraps correctly across midnight)
        var dist = (target - nowMins + 1440) % 1440;

        // At or just past target time (allow 1-min overshoot due to bg granularity)
        if (dist <= 1) {
            _fireAlarm("Target time");
            return;
        }

        // Not yet in the wake window
        if (dist > window) {
            _reschedule();
            return;
        }

        // Inside wake window — check biometrics for light sleep
        if (_isLightSleep()) {
            _fireAlarm("Smart wake");
        } else {
            _reschedule();
        }
    }

    // ── Sleep detection ───────────────────────────────────────────────────────
    // Biometrics-only — no live accelerometer in background mode.
    // Requires at least one signal; majority (≥ 50 %) must indicate sleep.

    private function _isLightSleep() as Boolean {
        var signals   = 0;
        var confirmed = 0;

        // Heart rate
        if (SensorHistory has :getHeartRateHistory) {
            var hrIter = SensorHistory.getHeartRateHistory(
                {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (hrIter != null) {
                var sample = hrIter.next();
                if (sample != null && sample.data != null) {
                    signals++;
                    var hr = sample.data as Number;
                    if (hr >= HR_SLEEP_MIN && hr <= HR_SLEEP_MAX) { confirmed++; }
                }
            }
        }

        // HRV (RMSSD)
        if (SensorHistory has :getHeartRateVariabilityHistory) {
            var hrvIter = SensorHistory.getHeartRateVariabilityHistory(
                {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (hrvIter != null) {
                var sample = hrvIter.next();
                if (sample != null && sample.data != null) {
                    signals++;
                    var hrv = 0;
                    if (sample.data instanceof Float) {
                        hrv = (sample.data as Float).toNumber();
                    } else {
                        hrv = sample.data as Number;
                    }
                    if (hrv >= HRV_LIGHT_MIN && hrv <= HRV_LIGHT_MAX) { confirmed++; }
                }
            }
        }

        // Respiration rate
        if (SensorHistory has :getRespirationRateHistory) {
            var respIter = SensorHistory.getRespirationRateHistory(
                {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (respIter != null) {
                var sample = respIter.next();
                if (sample != null && sample.data != null) {
                    signals++;
                    var resp = 0.0f;
                    if (sample.data instanceof Float) {
                        resp = sample.data as Float;
                    } else {
                        resp = (sample.data as Number).toFloat();
                    }
                    if (resp >= RESP_SLEEP_MIN && resp <= RESP_SLEEP_MAX) { confirmed++; }
                }
            }
        }

        // No biometric data available — don't false-fire
        if (signals == 0) { return false; }

        // Majority rule
        return confirmed * 2 >= signals;
    }

    // ── Alarm firing ──────────────────────────────────────────────────────────

    private function _fireAlarm(reason as String) as Void {
        // Remove running flag; background will not reschedule after this
        Application.Storage.deleteValue(KEY_RUNNING);

        // Store fired state so foreground can display it when user opens the app
        Application.Storage.setValue(KEY_BG_FIRED, true);
        Application.Storage.setValue(KEY_BG_FIRED_MINS, _nowMinutes());
        Application.Storage.setValue(KEY_BG_FIRED_REASON, reason);

        // Vibrate to wake the user
        if (Attention has :vibrate) {
            var patternSize = VIBE_REPEATS * 2 - 1;
            var pattern = new[patternSize] as Array<Attention.VibeProfile>;
            for (var i = 0; i < patternSize; i++) {
                if (i % 2 == 0) {
                    pattern[i] = new Attention.VibeProfile(VIBE_DUTY, VIBE_ON_MS);
                } else {
                    pattern[i] = new Attention.VibeProfile(0, VIBE_OFF_MS);
                }
            }
            Attention.vibrate(pattern);
        }

        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }

        // Alarm has fired — no further background scheduling needed
        Background.deleteTemporalEvent();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function _reschedule() as Void {
        // Re-register for 60 seconds from now (device minimum is ~1 minute)
        Background.registerForTemporalEvent(new Time.Duration(60));
    }

    private function _nowMinutes() as Number {
        var t = System.getClockTime();
        return t.hour * 60 + t.min;
    }
}
