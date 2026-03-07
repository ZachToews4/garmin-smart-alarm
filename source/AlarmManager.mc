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

    // Poll sensor every 30 seconds during the window
    private const POLL_INTERVAL_MS  = 30000;

    // Light-sleep thresholds (tunable)
    private const ACCEL_VAR_THRESH  = 50.0f;   // (mg)^2
    private const HR_SLEEP_MIN      = 40;
    private const HR_SLEEP_MAX      = 70;

    // Vibration pattern for alarm
    private const VIBE_DUTY         = 100;
    private const VIBE_ON_MS        = 500;
    private const VIBE_REPEATS      = 8;

    // ── State ─────────────────────────────────────────────────────────────────
    var isRunning       as Boolean = false;
    var alarmFired      as Boolean = false;
    var firedTime       as String  = "";

    var targetMinutes   as Number  = 0;
    var windowMinutes   as Number  = 20;

    var wakeTimeSet     as Boolean = false;

    private var _accelSamples as Array<Float> = [] as Array<Float>;
    private var _lastHR       as Number = 0;

    private var _pollTimer    as Timer.Timer? = null;
    private var _deadlineTimer as Timer.Timer? = null;

    // ── Init ──────────────────────────────────────────────────────────────────
    function initialize() {
    }

    // ── Public API ────────────────────────────────────────────────────────────

    function start() as Void {
        if (isRunning || !wakeTimeSet) { return; }

        isRunning  = true;
        alarmFired = false;
        firedTime  = "";

        // Enable HR sensor
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
        Sensor.enableSensorEvents(method(:onSensorData));

        // Schedule first sleep-check poll
        _pollTimer = new Timer.Timer();
        (_pollTimer as Timer.Timer).start(method(:onPollTimer), POLL_INTERVAL_MS, true);

        // Schedule hard deadline at targetMinutes
        var nowMins    = _nowMinutes();
        var minsUntil  = targetMinutes - nowMins;
        if (minsUntil < 0) { minsUntil += 1440; }
        var deadlineMs = minsUntil * 60000;
        _deadlineTimer = new Timer.Timer();
        (_deadlineTimer as Timer.Timer).start(method(:onDeadline), deadlineMs, false);

        WatchUi.requestUpdate();
    }

    function stop() as Void {
        isRunning = false;
        _stopTimers();
        Sensor.enableSensorEvents(null);
        WatchUi.requestUpdate();
    }

    // ── Sensor callback ───────────────────────────────────────────────────────

    function onSensorData(sensorInfo as Sensor.Info) as Void {
        // Capture HR
        if (sensorInfo.heartRate != null) {
            _lastHR = sensorInfo.heartRate as Number;
        }

        // Capture accel magnitude from Sensor.Info.accel ([x,y,z] in milli-g)
        if (sensorInfo.accel != null) {
            var accel = sensorInfo.accel as Array<Number>;
            if (accel.size() >= 3) {
                var x = accel[0].toFloat();
                var y = accel[1].toFloat();
                var z = accel[2].toFloat();
                var mag = Math.sqrt(x * x + y * y + z * z).toFloat();
                _accelSamples.add(mag);
                // Keep last 30 samples (~30 seconds of data at 1 Hz sensor rate)
                if (_accelSamples.size() > 30) {
                    _accelSamples = _accelSamples.slice(1, null) as Array<Float>;
                }
            }
        }
    }

    // ── Timer callbacks ───────────────────────────────────────────────────────

    function onPollTimer() as Void {
        if (!isRunning || alarmFired) { return; }
        if (!_inWakeWindow()) { return; }

        if (_isLightSleep()) {
            _fireAlarm("light sleep");
        }
    }

    function onDeadline() as Void {
        if (!isRunning || alarmFired) { return; }
        _fireAlarm("deadline");
    }

    // ── Sleep inference ───────────────────────────────────────────────────────

    private function _inWakeWindow() as Boolean {
        var nowMins = _nowMinutes();
        var distToTarget = (targetMinutes - nowMins + 1440) % 1440;
        return distToTarget <= windowMinutes;
    }

    private function _isLightSleep() as Boolean {
        var lowMovement = _isLowMovement();
        var sleepHR     = (_lastHR >= HR_SLEEP_MIN && _lastHR <= HR_SLEEP_MAX);
        return lowMovement && sleepHR;
    }

    private function _isLowMovement() as Boolean {
        if (_accelSamples.size() < 5) { return false; }

        var sum  = 0.0f;
        var size = _accelSamples.size();
        for (var i = 0; i < size; i++) {
            sum += _accelSamples[i];
        }
        var mean = sum / size;

        var varSum = 0.0f;
        for (var i = 0; i < size; i++) {
            var diff = _accelSamples[i] - mean;
            varSum += diff * diff;
        }
        var variance = varSum / size;

        return variance < ACCEL_VAR_THRESH;
    }

    // ── Alarm firing ──────────────────────────────────────────────────────────

    private function _fireAlarm(reason as String) as Void {
        alarmFired = true;
        firedTime  = _formatCurrentTime();

        _stopTimers();
        Sensor.enableSensorEvents(null);

        // Vibrate
        if (Attention has :vibrate) {
            var vibeData = new[VIBE_REPEATS] as Array<Attention.VibeProfile>;
            for (var i = 0; i < VIBE_REPEATS; i++) {
                vibeData[i] = new Attention.VibeProfile(VIBE_DUTY, VIBE_ON_MS);
            }
            Attention.vibrate(vibeData);
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
        var clockTime = System.getClockTime();
        return clockTime.hour * 60 + clockTime.min;
    }

    private function _formatCurrentTime() as String {
        var clockTime = System.getClockTime();
        var h = clockTime.hour;
        var m = clockTime.min;
        var ampm = "AM";
        if (!System.getDeviceSettings().is24Hour) {
            if (h >= 12) { ampm = "PM"; }
            if (h > 12)  { h -= 12; }
            if (h == 0)  { h = 12; }
            return h.format("%d") + ":" + m.format("%02d") + " " + ampm;
        }
        return h.format("%02d") + ":" + m.format("%02d");
    }

    function formatTargetTime() as String {
        if (!wakeTimeSet) { return "--:--"; }
        var h = targetMinutes / 60;
        var m = targetMinutes % 60;
        var ampm = "AM";
        if (!System.getDeviceSettings().is24Hour) {
            if (h >= 12) { ampm = "PM"; }
            if (h > 12)  { h -= 12; }
            if (h == 0)  { h = 12; }
            return h.format("%d") + ":" + m.format("%02d") + " " + ampm;
        }
        return h.format("%02d") + ":" + m.format("%02d");
    }
}
