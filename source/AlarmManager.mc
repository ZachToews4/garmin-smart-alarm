// AlarmManager.mc
// App state machine, settings persistence, and display refresh.
//
// All alarm detection logic now lives in AlarmBackground. This class:
//   • Manages settings (target time, window, snooze duration)
//   • Tracks app-level state (isRunning, alarmFired, snoozing, etc.)
//   • Owns a lightweight display-refresh timer (reads SensorHistory every 30 s)
//   • Registers / cancels the background temporal event
//   • Restores state on app open (background-fired alarm or mid-alarm resume)

import Toybox.Application;
import Toybox.Attention;
import Toybox.Background;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class AlarmManager {

    // ── Singleton ─────────────────────────────────────────────────────────────
    private static var _instance as AlarmManager? = null;

    static function getInstance() as AlarmManager {
        if (_instance == null) { _instance = new AlarmManager(); }
        return _instance as AlarmManager;
    }

    // ── App state (read-only by convention outside this class) ────────────────
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

    // ── Display data — refreshed from SensorHistory every 30 s ───────────────
    private var _lastHR        as Number  = 0;
    private var _hrAvailable   as Boolean = false;
    private var _lastHRV       as Number  = 0;
    private var _hrvAvailable  as Boolean = false;
    private var _lastResp      as Float   = 0.0f;
    private var _respAvailable as Boolean = false;

    private var _displayTimer as Timer.Timer? = null;
    private const DISPLAY_INTERVAL_MS = 30000;

    // ── Init ──────────────────────────────────────────────────────────────────
    function initialize() {
        _loadSettings();
        _restoreState();
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

    // ── Display accessors ─────────────────────────────────────────────────────
    function getLastHR()       as Number  { return _lastHR; }
    function isHrAvailable()   as Boolean { return _hrAvailable; }
    function getLastHRV()      as Number  { return _lastHRV; }
    function isHrvAvailable()  as Boolean { return _hrvAvailable; }
    function getLastResp()     as Float   { return _lastResp; }
    function isRespAvailable() as Boolean { return _respAvailable; }

    // ── Public API ────────────────────────────────────────────────────────────

    function start() as Void {
        if (isRunning || !wakeTimeSet) { return; }
        isRunning  = true;
        alarmFired = false;
        snoozing   = false;

        Application.Storage.setValue(KEY_RUNNING,    true);
        Application.Storage.setValue(KEY_START_MINS, _nowMinutes());
        Application.Storage.deleteValue(KEY_SLEEP_ONSET);
        Application.Storage.deleteValue(KEY_ONSET_COUNT);
        Application.Storage.deleteValue(KEY_SNOOZE_MODE);
        Application.Storage.deleteValue(KEY_SNOOZE_TARGET);

        _registerBackground();
        _startDisplayTimer();
        WatchUi.requestUpdate();
    }

    function stop() as Void {
        isRunning = false;
        snoozing  = false;

        Application.Storage.deleteValue(KEY_RUNNING);
        Application.Storage.deleteValue(KEY_SLEEP_ONSET);
        Application.Storage.deleteValue(KEY_ONSET_COUNT);
        Application.Storage.deleteValue(KEY_SNOOZE_MODE);
        Application.Storage.deleteValue(KEY_SNOOZE_TARGET);

        _cancelBackground();
        _stopDisplayTimer();
        WatchUi.requestUpdate();
    }

    function dismiss() as Void {
        alarmFired  = false;
        firedTime   = "";
        firedReason = "";
        WatchUi.requestUpdate();
    }

    function snooze() as Void {
        if (!alarmFired) { return; }
        alarmFired  = false;
        firedTime   = "";
        firedReason = "";
        isRunning   = true;
        snoozing    = true;

        var snoozeTarget = (_nowMinutes() + snoozeMinutes) % 1440;
        Application.Storage.setValue(KEY_RUNNING,      true);
        Application.Storage.setValue(KEY_SNOOZE_MODE,  true);
        Application.Storage.setValue(KEY_SNOOZE_TARGET, snoozeTarget);
        Application.Storage.deleteValue(KEY_SLEEP_ONSET);
        Application.Storage.deleteValue(KEY_ONSET_COUNT);

        _registerBackground();
        _startDisplayTimer();
        WatchUi.requestUpdate();
    }

    // Called by SmartAlarmApp.onStop() when the user exits while alarm is running.
    // Stops the display timer (foreground-only) but leaves all Storage intact
    // so AlarmBackground can continue monitoring.
    function suspendForeground() as Void {
        _stopDisplayTimer();
    }

    // Bypasses all sleep-detection conditions and fires immediately.
    // Use via menu → Test Alarm to verify vibration + fired screen on-device.
    function testFire() as Void {
        if (!isRunning) { return; }
        _doFire("Test");
    }

    // ── Internal fire (foreground-initiated — testFire only) ──────────────────
    private function _doFire(reason as String) as Void {
        alarmFired  = true;
        snoozing    = false;
        firedTime   = formatMinutes(_nowMinutes());
        firedReason = reason;
        isRunning   = false;

        Application.Storage.deleteValue(KEY_RUNNING);
        Application.Storage.deleteValue(KEY_SLEEP_ONSET);
        Application.Storage.deleteValue(KEY_ONSET_COUNT);
        Application.Storage.deleteValue(KEY_SNOOZE_MODE);
        Application.Storage.deleteValue(KEY_SNOOZE_TARGET);

        _cancelBackground();
        _stopDisplayTimer();

        if (Attention has :vibrate) {
            var patternSize = VIBE_REPEATS * 2 - 1;
            var pattern = new[patternSize] as Array<Attention.VibeProfile>;
            for (var i = 0; i < patternSize; i++) {
                pattern[i] = new Attention.VibeProfile(
                    i % 2 == 0 ? VIBE_DUTY : 0,
                    i % 2 == 0 ? VIBE_ON_MS : VIBE_OFF_MS
                );
            }
            Attention.vibrate(pattern);
        }
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }

        WatchUi.requestUpdate();
    }

    // ── State restoration on app open ─────────────────────────────────────────

    private function _restoreState() as Void {
        // Case 1: AlarmBackground fired the alarm while the app was closed.
        var bgFired = Application.Storage.getValue(KEY_BG_FIRED);
        if (bgFired != null && (bgFired as Boolean)) {
            var minsVal   = Application.Storage.getValue(KEY_BG_FIRED_MINS);
            var reasonVal = Application.Storage.getValue(KEY_BG_FIRED_REASON);
            alarmFired  = true;
            firedTime   = (minsVal   != null) ? formatMinutes(minsVal as Number) : "--:--";
            firedReason = (reasonVal != null) ? reasonVal as String : "Alarm";
            Application.Storage.deleteValue(KEY_BG_FIRED);
            Application.Storage.deleteValue(KEY_BG_FIRED_MINS);
            Application.Storage.deleteValue(KEY_BG_FIRED_REASON);
            return;
        }

        // Case 2: Alarm was running when user exited the app — resume monitoring.
        var running = Application.Storage.getValue(KEY_RUNNING);
        if (running == null || !(running as Boolean)) { return; }
        if (!wakeTimeSet) {
            Application.Storage.deleteValue(KEY_RUNNING);
            return;
        }

        var snoozeMode = Application.Storage.getValue(KEY_SNOOZE_MODE);
        isRunning = true;
        snoozing  = (snoozeMode != null && (snoozeMode as Boolean));

        // Re-register in case the background event expired while we were closed
        _registerBackground();
        _startDisplayTimer();
    }

    // ── Display refresh timer ─────────────────────────────────────────────────
    // Reads SensorHistory every 30 s so the monitoring screen stays current.

    private function _startDisplayTimer() as Void {
        _stopDisplayTimer();
        // Note: do NOT call onDisplayRefresh() here — this runs inside
        // initialize() before the view stack is set up. Let the timer fire
        // naturally; the display shows defaults until the first tick.
        _displayTimer = new Timer.Timer();
        (_displayTimer as Timer.Timer).start(method(:onDisplayRefresh), DISPLAY_INTERVAL_MS, true);
    }

    private function _stopDisplayTimer() as Void {
        if (_displayTimer != null) {
            (_displayTimer as Timer.Timer).stop();
            _displayTimer = null;
        }
    }

    // Public so the timer callback can resolve it via method(:onDisplayRefresh).
    // Reads SensorHistory directly — does NOT call SleepDetector (background use only).
    function onDisplayRefresh() as Void {
        if (SensorHistory has :getHeartRateHistory) {
            var hrIter = SensorHistory.getHeartRateHistory(
                {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (hrIter != null) {
                var s = hrIter.next();
                if (s != null && s.data != null) {
                    _lastHR = s.data as Number;
                    _hrAvailable = true;
                }
            }
        }

        if (SensorHistory has :getHeartRateVariabilityHistory) {
            var hrvIter = SensorHistory.getHeartRateVariabilityHistory(
                {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (hrvIter != null) {
                var s = hrvIter.next();
                if (s != null && s.data != null) {
                    if (s.data instanceof Float) {
                        _lastHRV = (s.data as Float).toNumber();
                    } else {
                        _lastHRV = s.data as Number;
                    }
                    _hrvAvailable = true;
                }
            }
        }

        if (SensorHistory has :getRespirationRateHistory) {
            var respIter = SensorHistory.getRespirationRateHistory(
                {:period => 2, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (respIter != null) {
                var s = respIter.next();
                if (s != null && s.data != null) {
                    if (s.data instanceof Float) {
                        _lastResp = s.data as Float;
                    } else {
                        _lastResp = (s.data as Number).toFloat();
                    }
                    _respAvailable = true;
                }
            }
        }

        WatchUi.requestUpdate();
    }

    // ── Background registration ───────────────────────────────────────────────

    private function _registerBackground() as Void {
        if (Background has :registerForTemporalEvent) {
            Background.registerForTemporalEvent(new Time.Duration(60));
        }
    }

    private function _cancelBackground() as Void {
        if (Background has :deleteTemporalEvent) {
            Background.deleteTemporalEvent();
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function _nowMinutes() as Number {
        var t = System.getClockTime();
        return t.hour * 60 + t.min;
    }

    // Public: used by MainView for current-time display (avoids duplicate logic).
    function formatMinutes(totalMins as Number) as String {
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
        return formatMinutes(targetMinutes);
    }
}
