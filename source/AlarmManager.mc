// AlarmManager.mc
// Singleton that owns all alarm + sleep-detection state and logic.

import Toybox.Application;
import Toybox.Attention;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
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

    private const POLL_INTERVAL_MS      = 30000;  // sleep-detect poll (30 s)
    private const ACCEL_MAX_SAMPLES     = 30;     // circular buffer capacity
    private const ACCEL_VAR_THRESH      = 50.0f;  // (mg)² — low-movement threshold

    // Heart rate
    private const HR_SLEEP_MIN          = 40;
    private const HR_SLEEP_MAX          = 70;
    private const HR_HISTORY_SIZE       = 5;      // rolling HR trend window (5 polls ≈ 2.5 min)
    private const HR_RISING_THRESH      = 3;      // bpm avg rise that flags a waking trend

    // Heart rate variability (RMSSD ms)
    private const HRV_LIGHT_MIN         = 20;     // below this suggests stress / wakefulness
    private const HRV_LIGHT_MAX         = 75;     // light-sleep range ceiling
    private const HRV_DEEP_THRESH       = 80;     // above this = likely deep sleep → hold off

    // Respiration (breaths/min)
    private const RESP_SLEEP_MIN        = 8.0f;
    private const RESP_SLEEP_MAX        = 16.0f;

    // Sustained movement
    private const SUSTAINED_POLLS       = 3;      // consecutive low-movement polls before qualifying

    // 90-minute sleep cycle
    private const CYCLE_MIN             = 90;     // minutes per sleep cycle
    private const CYCLE_WINDOW_MIN      = 15;     // ±min around boundary = light-sleep window
    private const ONSET_CONFIRM_POLLS   = 6;      // sustained polls to confirm sleep onset (~3 min)

    // Vibration
    private const VIBE_DUTY             = 100;
    private const VIBE_ON_MS            = 500;
    private const VIBE_OFF_MS           = 300;
    private const VIBE_REPEATS          = 8;

    // Deadline
    private const DEADLINE_CHUNK_MIN    = 60;

    // Pre-monitor delay
    private const PRE_MONITOR_DELAY_MIN = 30;     // min elapsed after start() before sleep detection

    // Storage keys — must also match AlarmBackground.mc for the BG_* keys
    private const KEY_TARGET          = "targetMinutes";
    private const KEY_WINDOW          = "windowMinutes";
    private const KEY_SNOOZE          = "snoozeMinutes";
    private const KEY_RUNNING         = "isRunning";
    private const KEY_START_MINS      = "startMinutes";
    // Set by AlarmBackground when it fires the alarm while app is closed
    private const KEY_BG_FIRED        = "bgFired";
    private const KEY_BG_FIRED_MINS   = "bgFiredTimeMins";
    private const KEY_BG_FIRED_REASON = "bgFiredReason";

    // ── Public state (read-only by convention) ────────────────────────────────
    var isRunning   as Boolean = false;
    var alarmFired  as Boolean = false;
    var snoozing    as Boolean = false;
    var firedTime   as String  = "";
    var firedReason as String  = "";
    var wakeTimeSet as Boolean = false;

    // ── Settings ──────────────────────────────────────────────────────────────
    var targetMinutes as Number = 0;
    var windowMinutes as Number = 20;
    var snoozeMinutes as Number = 5;

    // ── Private sensor state ──────────────────────────────────────────────────
    private var _accelSamples as Array<Float>  = [] as Array<Float>;
    private var _accelHead    as Number  = 0;

    private var _lastHR       as Number  = 0;
    private var _hrAvailable  as Boolean = false;
    private var _hrHistory    as Array<Number> = [] as Array<Number>;  // one entry per poll

    private var _lastHRV      as Number  = 0;
    private var _hrvAvailable as Boolean = false;

    private var _lastResp     as Float   = 0.0f;
    private var _respAvailable as Boolean = false;

    // Sustained movement counter — incremented each poll with low movement,
    // reset to 0 on any high-movement poll.
    private var _lowMovementCount as Number = 0;

    // Sleep onset detection
    private var _sleepOnsetMins as Number = -1;  // -1 = not detected yet

    private var _startMinutes as Number  = 0;
    private var _pollTimer     as Timer.Timer? = null;
    private var _deadlineTimer as Timer.Timer? = null;

    // ── Init ──────────────────────────────────────────────────────────────────
    function initialize() {
        _loadSettings();
        _restoreIfRunning();
    }

    // ── Settings persistence ──────────────────────────────────────────────────

    private function _loadSettings() as Void {
        var t = Application.Storage.getValue(KEY_TARGET);
        if (t != null) { targetMinutes = t as Number; wakeTimeSet = true; }
        var w = Application.Storage.getValue(KEY_WINDOW);
        if (w != null) { windowMinutes = w as Number; }
        var s = Application.Storage.getValue(KEY_SNOOZE);
        if (s != null) { snoozeMinutes = s as Number; }
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

    function setSnoozeMinutes(minutes as Number) as Void {
        snoozeMinutes = minutes;
        Application.Storage.setValue(KEY_SNOOZE, snoozeMinutes);
    }

    // ── Sensor data accessors (for UI display) ────────────────────────────────
    function getLastHR()       as Number  { return _lastHR; }
    function isHrAvailable()   as Boolean { return _hrAvailable; }
    function getLastHRV()      as Number  { return _lastHRV; }
    function isHrvAvailable()  as Boolean { return _hrvAvailable; }
    function getLastResp()     as Float   { return _lastResp; }
    function isRespAvailable() as Boolean { return _respAvailable; }

    // ── Public API ────────────────────────────────────────────────────────────

    function start() as Void {
        if (isRunning || !wakeTimeSet) { return; }
        _activate(_nowMinutes());
        WatchUi.requestUpdate();
    }

    function stop() as Void {
        isRunning = false;
        snoozing  = false;
        _stopTimers();
        Sensor.enableSensorEvents(null);
        Application.Storage.deleteValue(KEY_RUNNING);
        // Cancel background service — alarm is fully stopped
        if (Background has :deleteTemporalEvent) {
            Background.deleteTemporalEvent();
        }
        WatchUi.requestUpdate();
    }

    // Called by SmartAlarmApp.onStop() when the user exits the app while the
    // alarm is still running. Stops foreground-only resources (live sensor,
    // timers) but leaves Storage intact so AlarmBackground can take over.
    function suspendForeground() as Void {
        _stopTimers();
        Sensor.enableSensorEvents(null);
        // KEY_RUNNING stays true in Storage — background service monitors it.
        // Background temporal event stays registered.
    }

    function dismiss() as Void {
        alarmFired  = false;
        firedTime   = "";
        firedReason = "";
        WatchUi.requestUpdate();
    }

    // Immediately fires the alarm without any sleep-detection conditions.
    // Used for testing — confirms vibration and the fired screen both work.
    function testFire() as Void {
        if (!isRunning) { return; }
        _fireAlarm("Test");
    }

    function snooze() as Void {
        if (!alarmFired) { return; }
        alarmFired  = false;
        firedTime   = "";
        firedReason = "";
        isRunning   = true;
        snoozing    = true;

        _resetSensorState();
        Sensor.enableSensorEvents(method(:onSensorData));
        _pollTimer = new Timer.Timer();
        (_pollTimer as Timer.Timer).start(method(:onPollTimer), POLL_INTERVAL_MS, true);
        _scheduleDeadline(snoozeMinutes);
        WatchUi.requestUpdate();
    }

    // ── Internal activation ───────────────────────────────────────────────────

    private function _activate(startMins as Number) as Void {
        isRunning     = true;
        alarmFired    = false;
        snoozing      = false;
        firedTime     = "";
        firedReason   = "";
        _startMinutes = startMins;

        Application.Storage.setValue(KEY_RUNNING,    true);
        Application.Storage.setValue(KEY_START_MINS, startMins);

        // Register background service to keep alarm alive when app is closed
        if (Background has :registerForTemporalEvent) {
            Background.registerForTemporalEvent(new Time.Duration(60));
        }

        _resetSensorState();
        Sensor.enableSensorEvents(method(:onSensorData));

        _pollTimer = new Timer.Timer();
        (_pollTimer as Timer.Timer).start(method(:onPollTimer), POLL_INTERVAL_MS, true);

        var minsLeft = (targetMinutes - _nowMinutes() + 1440) % 1440;
        if (minsLeft == 0) { minsLeft = 1440; }
        _scheduleDeadline(minsLeft);
    }

    private function _resetSensorState() as Void {
        _accelSamples     = [] as Array<Float>;
        _accelHead        = 0;
        _lastHR           = 0;
        _hrAvailable      = false;
        _hrHistory        = [] as Array<Number>;
        _lastHRV          = 0;
        _hrvAvailable     = false;
        _lastResp         = 0.0f;
        _respAvailable    = false;
        _lowMovementCount = 0;
        _sleepOnsetMins   = -1;
    }

    private function _restoreIfRunning() as Void {
        // Check if AlarmBackground fired the alarm while the app was closed.
        // If so, restore the fired state for display — don't re-activate.
        var bgFired = Application.Storage.getValue(KEY_BG_FIRED);
        if (bgFired != null && (bgFired as Boolean)) {
            var firedMinsVal   = Application.Storage.getValue(KEY_BG_FIRED_MINS);
            var firedReasonVal = Application.Storage.getValue(KEY_BG_FIRED_REASON);
            alarmFired  = true;
            firedTime   = (firedMinsVal   != null)
                ? _formatMinutesOfDay(firedMinsVal as Number)
                : "--:--";
            firedReason = (firedReasonVal != null)
                ? firedReasonVal as String
                : "Alarm";
            // Clear background fired flags — foreground has picked them up
            Application.Storage.deleteValue(KEY_BG_FIRED);
            Application.Storage.deleteValue(KEY_BG_FIRED_MINS);
            Application.Storage.deleteValue(KEY_BG_FIRED_REASON);
            return;
        }

        // Normal case: alarm was running when the user exited the app
        var wasRunning = Application.Storage.getValue(KEY_RUNNING);
        if (wasRunning == null || !(wasRunning as Boolean)) { return; }
        if (!wakeTimeSet) {
            Application.Storage.deleteValue(KEY_RUNNING);
            return;
        }
        var stored    = Application.Storage.getValue(KEY_START_MINS);
        var startMins = (stored != null) ? stored as Number : _nowMinutes();
        try {
            _activate(startMins);
        } catch (ex instanceof Lang.Exception) {
            // If restore fails for any reason, clear the flag so we don't
            // crash-loop on every subsequent app open.
            Application.Storage.deleteValue(KEY_RUNNING);
            isRunning = false;
        }
    }

    // ── Deadline scheduling ───────────────────────────────────────────────────

    private function _scheduleDeadline(minsLeft as Number) as Void {
        if (_deadlineTimer != null) {
            (_deadlineTimer as Timer.Timer).stop();
            _deadlineTimer = null;
        }
        _deadlineTimer = new Timer.Timer();
        if (minsLeft > DEADLINE_CHUNK_MIN) {
            (_deadlineTimer as Timer.Timer).start(
                method(:onDeadlineCheckpoint), DEADLINE_CHUNK_MIN * 60000, false);
        } else {
            (_deadlineTimer as Timer.Timer).start(
                method(:onDeadline), minsLeft * 60000, false);
        }
    }

    // ── Sensor callback ───────────────────────────────────────────────────────

    function onSensorData(info as Sensor.Info) as Void {
        if (info.heartRate != null) {
            _lastHR      = info.heartRate as Number;
            _hrAvailable = true;
        }

        if (info.accel != null) {
            var accel = info.accel as Array<Number>;
            if (accel.size() >= 3) {
                var x   = accel[0].toFloat();
                var y   = accel[1].toFloat();
                var z   = accel[2].toFloat();
                var mag = Math.sqrt(x * x + y * y + z * z).toFloat();

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

        // Update per-poll state (movement counter, HR trend history)
        _updatePollState();

        if (snoozing) {
            // During snooze: no window or cycle constraints
            if (_isLightSleep()) { _fireAlarm("Smart wake"); }
            return;
        }

        // Track sleep onset even before we enter the wake window
        _checkSleepOnset();

        if (!_inWakeWindow()) { return; }
        if (_isLightSleep())  { _fireAlarm("Smart wake"); }
    }

    function onDeadlineCheckpoint() as Void {
        if (!isRunning || alarmFired) { return; }
        var minsLeft = (targetMinutes - _nowMinutes() + 1440) % 1440;
        if (minsLeft == 0) {
            _fireAlarm(snoozing ? "Snooze" : "Target time");
        } else {
            _scheduleDeadline(minsLeft);
        }
    }

    function onDeadline() as Void {
        if (!isRunning || alarmFired) { return; }
        _fireAlarm(snoozing ? "Snooze" : "Target time");
    }

    // ── Per-poll state update ─────────────────────────────────────────────────

    private function _updatePollState() as Void {
        // Sustained movement counter
        if (_isLowMovement()) {
            _lowMovementCount++;
        } else {
            _lowMovementCount = 0;
        }

        // HR trend history — one sample per poll (every 30 s)
        if (_hrAvailable) {
            if (_hrHistory.size() < HR_HISTORY_SIZE) {
                _hrHistory.add(_lastHR);
            } else {
                // Shift left to make room for newest reading
                for (var i = 0; i < HR_HISTORY_SIZE - 1; i++) {
                    _hrHistory[i] = _hrHistory[i + 1];
                }
                _hrHistory[HR_HISTORY_SIZE - 1] = _lastHR;
            }
        }

        // HRV — not reliably available on Sensor.Info (dict access throws on Venu 2);
        // pull from SensorHistory instead. 'has' check is safe on unsupported devices.
        if (SensorHistory has :getHeartRateVariabilityHistory) {
            var hrvIter = SensorHistory.getHeartRateVariabilityHistory(
                {:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (hrvIter != null) {
                var hrvSample = hrvIter.next();
                if (hrvSample != null && hrvSample.data != null) {
                    if (hrvSample.data instanceof Float) {
                        _lastHRV = (hrvSample.data as Float).toNumber();
                    } else {
                        _lastHRV = hrvSample.data as Number;
                    }
                    _hrvAvailable = true;
                }
            }
        }

        // Respiration rate — also via SensorHistory for the same reason.
        if (SensorHistory has :getRespirationRateHistory) {
            var respIter = SensorHistory.getRespirationRateHistory(
                {:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (respIter != null) {
                var respSample = respIter.next();
                if (respSample != null && respSample.data != null) {
                    if (respSample.data instanceof Float) {
                        _lastResp = respSample.data as Float;
                    } else {
                        _lastResp = (respSample.data as Number).toFloat();
                    }
                    _respAvailable = true;
                }
            }
        }
    }

    // ── Sleep onset auto-detection ────────────────────────────────────────────
    // Records the first time the user appears to be genuinely asleep, so we
    // can align subsequent checks to 90-minute sleep cycle boundaries.

    private function _checkSleepOnset() as Void {
        if (_sleepOnsetMins >= 0) { return; }  // already detected

        // Require extended sustained low movement + at least one sleep biometric
        if (_lowMovementCount < ONSET_CONFIRM_POLLS) { return; }

        var biometricsOk = false;
        if (_hrAvailable && _lastHR >= HR_SLEEP_MIN && _lastHR <= HR_SLEEP_MAX) {
            biometricsOk = true;
        }
        if (_respAvailable && _lastResp >= RESP_SLEEP_MIN && _lastResp <= RESP_SLEEP_MAX) {
            biometricsOk = true;
        }
        // Fall back to movement-only if no biometrics have arrived at all
        if (!_hrAvailable && !_respAvailable && !_hrvAvailable) {
            biometricsOk = true;
        }

        if (biometricsOk) {
            _sleepOnsetMins = _nowMinutes();
        }
    }

    // ── Sleep cycle window ────────────────────────────────────────────────────
    // Returns true when we're near a 90-minute cycle boundary (±CYCLE_WINDOW_MIN).
    // Light sleep naturally occurs at these transitions — we relax thresholds here
    // and tighten them mid-cycle (likely deep sleep).

    private function _inCycleWindow() as Boolean {
        if (_sleepOnsetMins < 0) { return true; }  // no onset yet → don't constrain

        var elapsed  = (_nowMinutes() - _sleepOnsetMins + 1440) % 1440;
        var cyclePos = elapsed % CYCLE_MIN;

        // Near the end of a cycle or the very start of the next one
        return cyclePos <= CYCLE_WINDOW_MIN ||
               cyclePos >= (CYCLE_MIN - CYCLE_WINDOW_MIN);
    }

    // ── Wake window ───────────────────────────────────────────────────────────

    private function _inWakeWindow() as Boolean {
        var nowMins = _nowMinutes();

        // Pre-monitor delay: cap to half the window so short windows still work
        var halfWindow    = windowMinutes / 2;
        var effectiveDelay = PRE_MONITOR_DELAY_MIN < halfWindow
            ? PRE_MONITOR_DELAY_MIN
            : halfWindow;

        var elapsed = (nowMins - _startMinutes + 1440) % 1440;
        if (elapsed < effectiveDelay) { return false; }

        var dist = (targetMinutes - nowMins + 1440) % 1440;
        return dist <= windowMinutes;
    }

    // ── Sleep state inference ─────────────────────────────────────────────────

    // Gate 1: require sustained low movement
    private function _isSustainedLowMovement() as Boolean {
        return _lowMovementCount >= SUSTAINED_POLLS;
    }

    // Low movement at this instant (raw buffer check)
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

    // HR signal: all recent values in sleep range AND not trending upward
    private function _isHrSignalOk() as Boolean {
        if (!_hrAvailable) { return false; }

        var n = _hrHistory.size();
        if (n < 2) {
            // Not enough history yet — use single reading
            return _lastHR >= HR_SLEEP_MIN && _lastHR <= HR_SLEEP_MAX;
        }

        // All historical values must be within sleep range
        for (var i = 0; i < n; i++) {
            if (_hrHistory[i] < HR_SLEEP_MIN || _hrHistory[i] > HR_SLEEP_MAX) {
                return false;
            }
        }

        // Reject rising HR trend — indicates waking, not sleeping
        if (n >= 3) {
            var recentAvg = (_hrHistory[n-1] + _hrHistory[n-2]) / 2;
            var olderAvg  = (_hrHistory[0]   + _hrHistory[1])   / 2;
            if (recentAvg > olderAvg + HR_RISING_THRESH) { return false; }
        }

        return true;
    }

    // HRV signal: in light-sleep range (not so high as to suggest deep sleep)
    private function _isHrvSignalOk() as Boolean {
        if (!_hrvAvailable) { return false; }
        return _lastHRV >= HRV_LIGHT_MIN && _lastHRV <= HRV_LIGHT_MAX;
    }

    // Respiration signal: within sleep range
    private function _isRespSignalOk() as Boolean {
        if (!_respAvailable) { return false; }
        return _lastResp >= RESP_SLEEP_MIN && _lastResp <= RESP_SLEEP_MAX;
    }

    // Main sleep stage decision: multi-signal scoring engine
    private function _isLightSleep() as Boolean {
        // Gate 1: must have sustained low movement
        if (!_isSustainedLowMovement()) { return false; }

        // Gate 2: strong HRV evidence of deep sleep → hold off even in cycle window
        if (_hrvAvailable && _lastHRV > HRV_DEEP_THRESH) { return false; }

        // Score available biometric signals
        var signals   = 0;
        var confirmed = 0;

        if (_hrAvailable)   { signals++; if (_isHrSignalOk())   { confirmed++; } }
        if (_hrvAvailable)  { signals++; if (_isHrvSignalOk())  { confirmed++; } }
        if (_respAvailable) { signals++; if (_isRespSignalOk()) { confirmed++; } }

        // No biometrics available: use cycle window as the sole gate
        if (signals == 0) { return _inCycleWindow(); }

        var inWindow = _inCycleWindow();

        if (inWindow) {
            // Near cycle boundary: require majority (≥50%) of signals to agree
            return confirmed * 2 >= signals;
        } else {
            // Mid-cycle (likely deep sleep): require strong majority (≥75%)
            return confirmed * 4 >= signals * 3;
        }
    }

    // ── Alarm firing ──────────────────────────────────────────────────────────

    private function _fireAlarm(reason as String) as Void {
        alarmFired  = true;
        snoozing    = false;
        firedTime   = _formatMinutesOfDay(_nowMinutes());
        firedReason = reason;

        _stopTimers();
        Sensor.enableSensorEvents(null);
        Application.Storage.deleteValue(KEY_RUNNING);
        // Cancel background service — foreground already fired the alarm
        if (Background has :deleteTemporalEvent) {
            Background.deleteTemporalEvent();
        }

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
