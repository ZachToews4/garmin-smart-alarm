// AlarmManager.mc
// Singleton that owns all alarm + sleep-detection state and logic.

import Toybox.Application;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class AlarmManager {

    // ── Singleton ─────────────────────────────────────────────────────────────
    private static var _instance as AlarmManager? = null;

    static function getInstance() as AlarmManager {
        if (_instance == null) {
            _instance = new AlarmManager();
        }
        return _instance as AlarmManager;
    }

    // ── Constants ─────────────────────────────────────────────────────────────

    private const POLL_INTERVAL_MS  = 30000;   // check every 30 s in wake window
    private const ACCEL_MAX_SAMPLES = 30;       // circular buffer capacity
    private const ACCEL_VAR_THRESH  = 50.0f;   // (mg)^2 — low-movement threshold
    private const HR_SLEEP_MIN      = 40;
    private const HR_SLEEP_MAX      = 70;
    private const VIBE_DUTY         = 100;
    private const VIBE_ON_MS        = 500;
    private const VIBE_REPEATS      = 8;

    // Storage keys
    private const KEY_TARGET  = "targetMinutes";
    private const KEY_WINDOW  = "windowMinutes";

    // ── Public state (read-only by convention) ────────────────────────────────
    var isRunning    as Boolean = false;
    var alarmFired   as Boolean = false;
    var firedTime    as String  = "";
    var firedReason  as String  = "";   // "Smart wake" | "Target time"
    var wakeTimeSet  as Boolean = false;

    // ── Settings (mutate via setters to auto-persist) ─────────────────────────
    var targetMinutes as Number = 0;
    var windowMinutes as Number = 20;

    // ── Private sensor state ──────────────────────────────────────────────────
    private var _accelSamples as Array<Float> = [] as Array<Float>;
    private var _accelHead    as Number = 0;   // next write index (circular)
    private var _lastHR       as Number = 0;

    private var _pollTimer     as Timer.Timer? = null;
    private var _deadlineTimer as Timer.Timer? = null;

    // ── Init ──────────────────────────────────────────────────────────────────
    function initialize() {
        _loadSettings();
    }

    // ── Settings persistence ──────────────────────────────────────────────────

    private function _loadSettings() as Void {
        var t = Application.Storage.getValue(KEY_TARGET);
        if (t != null) {
            targetMinutes = t as Number;
            wakeTimeSet   = true;
        }
        var w = Application.Storage.getValue(KEY_WINDOW);
        if (w != null) {
            windowMinutes = w as Number;
        }
    }

    function setWakeTime(hour as Number, minute as Number) as Void {
        targetMinutes = hour * 60 + minute;
        wakeTimeSet   = true;
        Application.Storage.setValue(KEY_TARGET, targetMinutes);
    }

    function setWindow(minutes as Number) as Void {
        windowMinutes = minutes;
        Application.Storage.setValue(KEY_WINDOW, windowMinutes);
    }

    // ── Public API ────────────────────────────────────────────────────────────

    function start() as Void {
        if (isRunning || !wakeTimeSet) { return; }

        isRunning   = true;
        alarmFired  = false;
        firedTime   = "";
        firedReason = "";

        // Enable sensors — enableSensorEvents covers built-in HR + accel.
        // setEnabledSensors is for external (ANT+/BT) sensors only; omitting
        // it leaves all internal sensors active.
        Sensor.enableSensorEvents(method(:onSensorData));

        // Periodic sleep-detection poll
        _pollTimer = new Timer.Timer();
        (_pollTimer as Timer.Timer).start(method(:onPollTimer), POLL_INTERVAL_MS, true);

        // Hard deadline timer
        var nowMins   = _nowMinutes();
        var minsLeft  = (targetMinutes - nowMins + 1440) % 1440;
        if (minsLeft == 0) { minsLeft = 1440; }  // don't fire immediately
        _deadlineTimer = new Timer.Timer();
        (_deadlineTimer as Timer.Timer).start(method(:onDeadline), minsLeft * 60000, false);

        WatchUi.requestUpdate();
    }

    function stop() as Void {
        isRunning = false;
        _stopTimers();
        Sensor.enableSensorEvents(null);
        WatchUi.requestUpdate();
    }

    // ── Sensor callback ───────────────────────────────────────────────────────

    function onSensorData(info as Sensor.Info) as Void {
        if (info.heartRate != null) {
            _lastHR = info.heartRate as Number;
        }

        if (info.accel != null) {
            var accel = info.accel as Array<Number>;
            if (accel.size() >= 3) {
                var x   = accel[0].toFloat();
                var y   = accel[1].toFloat();
                var z   = accel[2].toFloat();
                var mag = Math.sqrt(x * x + y * y + z * z).toFloat();

                // Circular buffer — overwrite oldest sample once full
                if (_accelSamples.size() < ACCEL_MAX_SAMPLES) {
                    _accelSamples.add(mag);
                } else {
                    _accelSamples[_accelHead] = mag;
                }
                _accelHead = (_accelHead + 1) % ACCEL_MAX_SAMPLES;
            }
        }
    }

    // ── Timer callbacks ───────────────────────────────────────────────────────

    function onPollTimer() as Void {
        if (!isRunning || alarmFired) { return; }
        if (!_inWakeWindow())         { return; }
        if (_isLightSleep())          { _fireAlarm("Smart wake"); }
    }

    function onDeadline() as Void {
        if (!isRunning || alarmFired) { return; }
        _fireAlarm("Target time");
    }

    // ── Sleep inference ───────────────────────────────────────────────────────

    private function _inWakeWindow() as Boolean {
        var dist = (targetMinutes - _nowMinutes() + 1440) % 1440;
        return dist <= windowMinutes;
    }

    private function _isLightSleep() as Boolean {
        return _isLowMovement() && (_lastHR >= HR_SLEEP_MIN && _lastHR <= HR_SLEEP_MAX);
    }

    private function _isLowMovement() as Boolean {
        var n = _accelSamples.size();
        if (n < 5) { return false; }

        var sum = 0.0f;
        for (var i = 0; i < n; i++) { sum += _accelSamples[i]; }
        var mean = sum / n;

        var varSum = 0.0f;
        for (var i = 0; i < n; i++) {
            var d = _accelSamples[i] - mean;
            varSum += d * d;
        }
        return (varSum / n) < ACCEL_VAR_THRESH;
    }

    // ── Alarm firing ──────────────────────────────────────────────────────────

    private function _fireAlarm(reason as String) as Void {
        alarmFired  = true;
        firedTime   = _formatMinutesOfDay(_nowMinutes());
        firedReason = reason;

        _stopTimers();
        Sensor.enableSensorEvents(null);

        if (Attention has :vibrate) {
            var pattern = new[VIBE_REPEATS] as Array<Attention.VibeProfile>;
            for (var i = 0; i < VIBE_REPEATS; i++) {
                pattern[i] = new Attention.VibeProfile(VIBE_DUTY, VIBE_ON_MS);
            }
            Attention.vibrate(pattern);
        }

        isRunning = false;
        WatchUi.requestUpdate();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function _stopTimers() as Void {
        if (_pollTimer != null) {
            (_pollTimer as Timer.Timer).stop();
            _pollTimer = null;
        }
        if (_deadlineTimer != null) {
            (_deadlineTimer as Timer.Timer).stop();
            _deadlineTimer = null;
        }
    }

    private function _nowMinutes() as Number {
        var t = System.getClockTime();
        return t.hour * 60 + t.min;
    }

    // Shared formatter: total minutes-of-day → display string
    private function _formatMinutesOfDay(totalMins as Number) as String {
        var h = totalMins / 60;
        var m = totalMins % 60;
        if (!System.getDeviceSettings().is24Hour) {
            var ampm = (h >= 12) ? "PM" : "AM";
            if (h > 12) { h -= 12; }
            if (h == 0) { h = 12; }
            return h.format("%d") + ":" + m.format("%02d") + " " + ampm;
        }
        return h.format("%02d") + ":" + m.format("%02d");
    }

    function formatTargetTime() as String {
        if (!wakeTimeSet) { return "--:--"; }
        return _formatMinutesOfDay(targetMinutes);
    }
}
