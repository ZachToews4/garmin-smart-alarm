// MainView.mc
// Primary watchface-style view.

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

class MainView extends WatchUi.View {

    private var _alarmMgr as AlarmManager;

    function initialize() {
        View.initialize();
        _alarmMgr = AlarmManager.getInstance();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        // No XML layout — all drawing is done in onUpdate.
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width  = dc.getWidth();
        var height = dc.getHeight();
        var cx     = width  / 2;
        var cy     = height / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_alarmMgr.alarmFired) {
            _drawFiredScreen(dc, cx, cy, width, height);
        } else if (_alarmMgr.snoozing) {
            _drawSnoozeScreen(dc, cx, cy, width, height);
        } else if (_alarmMgr.isRunning) {
            _drawMonitoringScreen(dc, cx, cy, width, height);
        } else {
            _drawIdleScreen(dc, cx, cy, width, height);
        }
    }

    // ── Shared layout helpers ─────────────────────────────────────────────────

    // Draws wake time + window — identical between idle and monitoring screens.
    private function _drawCommonInfo(
        dc     as Graphics.Dc,
        cx     as Number, cy     as Number,
        width  as Number, height as Number) as Void {

        // Wake Time label
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (height * 0.30).toNumber(),
            Graphics.FONT_TINY, "Wake Time", Graphics.TEXT_JUSTIFY_CENTER);

        // Wake Time value
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (height * 0.19).toNumber(),
            Graphics.FONT_NUMBER_MEDIUM,
            _alarmMgr.formatTargetTime(), Graphics.TEXT_JUSTIFY_CENTER);

        // Window
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (height * 0.10).toNumber(),
            Graphics.FONT_SMALL,
            "Window: " + _alarmMgr.windowMinutes + " min",
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Draws battery percentage in the top-right corner.
    // Shown in orange when below 20 % as a low-battery warning.
    private function _drawBattery(dc as Graphics.Dc, width as Number) as Void {
        var battery = System.getSystemStats().battery;
        var color   = (battery < 20.0f)
            ? Graphics.COLOR_ORANGE
            : Graphics.COLOR_DK_GRAY;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 8, 8, Graphics.FONT_TINY,
            battery.toNumber().toString() + "%",
            Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ── Idle (setup) screen ───────────────────────────────────────────────────
    private function _drawIdleScreen(
        dc as Graphics.Dc,
        cx as Number, cy as Number,
        width as Number, height as Number) as Void {

        _drawBattery(dc, width);

        // App title
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.07).toNumber(),
            Graphics.FONT_TINY, "Smart Alarm", Graphics.TEXT_JUSTIFY_CENTER);

        _drawCommonInfo(dc, cx, cy, width, height);

        // Hint
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - (height * 0.18).toNumber(),
            Graphics.FONT_TINY, "Tap to configure", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Monitoring screen ─────────────────────────────────────────────────────
    private function _drawMonitoringScreen(
        dc as Graphics.Dc,
        cx as Number, cy as Number,
        width as Number, height as Number) as Void {

        _drawBattery(dc, width);

        // Green status dot + label
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, (height * 0.08).toNumber(), 8);
        dc.drawText(cx, (height * 0.11).toNumber(),
            Graphics.FONT_TINY, "Monitoring", Graphics.TEXT_JUSTIFY_CENTER);

        _drawCommonInfo(dc, cx, cy, width, height);

        // ── Sensor status rows ────────────────────────────────────────────────
        var hrStr = _alarmMgr.isHrAvailable()
            ? ("HR: " + _alarmMgr.getLastHR() + " bpm")
            : "HR: --";
        var hrColor = _alarmMgr.isHrAvailable()
            ? Graphics.COLOR_RED
            : Graphics.COLOR_DK_GRAY;
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (height * 0.21).toNumber(),
            Graphics.FONT_TINY, hrStr, Graphics.TEXT_JUSTIFY_CENTER);

        var recoveryStr = "Stress: --   BB: --";
        if (_alarmMgr.isStressAvailable() || _alarmMgr.isBodyBatteryAvailable()) {
            var stressPart = _alarmMgr.isStressAvailable()
                ? ("Stress: " + _alarmMgr.getLastStress())
                : "Stress: --";
            var bodyPart = _alarmMgr.isBodyBatteryAvailable()
                ? ("BB: " + _alarmMgr.getLastBodyBattery())
                : "BB: --";
            recoveryStr = stressPart + "   " + bodyPart;
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (height * 0.28).toNumber(),
            Graphics.FONT_TINY, recoveryStr, Graphics.TEXT_JUSTIFY_CENTER);

        if (_alarmMgr.isDebugMode()) {
            var accelStr = _alarmMgr.isAccelAvailable()
                ? ("Accel |g|: " + _alarmMgr.getLiveAccelMag().format("%.2f"))
                : "Accel |g|: --";
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy + (height * 0.35).toNumber(),
                Graphics.FONT_TINY, accelStr, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Current time (bottom) — respects device 12/24h setting
        var clk     = System.getClockTime();
        var nowMins = clk.hour * 60 + clk.min;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - (height * 0.14).toNumber(),
            Graphics.FONT_TINY,
            _alarmMgr.formatMinutes(nowMins), Graphics.TEXT_JUSTIFY_CENTER);

        // Subtle hint: Back is blocked, menu is the only way to cancel
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - (height * 0.05).toNumber(),
            Graphics.FONT_TINY, "Press \u25CF to cancel", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Snooze screen ─────────────────────────────────────────────────────────
    private function _drawSnoozeScreen(
        dc as Graphics.Dc,
        cx as Number, cy as Number,
        width as Number, height as Number) as Void {

        _drawBattery(dc, width);

        // Snooze indicator (three Z's)
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.10).toNumber(),
            Graphics.FONT_MEDIUM, "z z z", Graphics.TEXT_JUSTIFY_CENTER);

        // "Snoozed" title
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (height * 0.12).toNumber(),
            Graphics.FONT_MEDIUM, "Snoozed", Graphics.TEXT_JUSTIFY_CENTER);

        // Snooze duration — driven by the actual setting, not a hardcoded string
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (height * 0.04).toNumber(),
            Graphics.FONT_SMALL,
            "+ " + _alarmMgr.snoozeMinutes + " min",
            Graphics.TEXT_JUSTIFY_CENTER);

        // Hint
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - (height * 0.18).toNumber(),
            Graphics.FONT_TINY, "Back to cancel", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Alarm fired screen ────────────────────────────────────────────────────
    private function _drawFiredScreen(
        dc as Graphics.Dc,
        cx as Number, cy as Number,
        width as Number, height as Number) as Void {

        // Wake icon: sun circle + rays
        var sunY = (height * 0.13).toNumber();
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, sunY, 18);
        for (var i = 0; i < 8; i++) {
            var angle = (i * 45) * Math.PI / 180.0;
            var x1 = (cx   + 24 * Math.cos(angle)).toNumber();
            var y1 = (sunY + 24 * Math.sin(angle)).toNumber();
            var x2 = (cx   + 32 * Math.cos(angle)).toNumber();
            var y2 = (sunY + 32 * Math.sin(angle)).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }

        // "Good morning!"
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (height * 0.26).toNumber(),
            Graphics.FONT_MEDIUM, "Good morning!", Graphics.TEXT_JUSTIFY_CENTER);

        // Fire reason badge
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (height * 0.10).toNumber(),
            Graphics.FONT_TINY, _alarmMgr.firedReason, Graphics.TEXT_JUSTIFY_CENTER);

        // Fired time
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (height * 0.02).toNumber(),
            Graphics.FONT_NUMBER_MEDIUM,
            _alarmMgr.firedTime, Graphics.TEXT_JUSTIFY_CENTER);

        // Action hints — snooze duration reflects the actual setting
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - (height * 0.18).toNumber(),
            Graphics.FONT_TINY,
            "Tap = Snooze " + _alarmMgr.snoozeMinutes + " min  |  Back = Dismiss",
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}
