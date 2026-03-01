// MainView.mc
// Primary watchface-style view.

import Toybox.Graphics;
import Toybox.Lang;
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

        // Background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_alarmMgr.alarmFired) {
            _drawFiredScreen(dc, cx, cy, width, height);
        } else if (_alarmMgr.isRunning) {
            _drawMonitoringScreen(dc, cx, cy, width, height);
        } else {
            _drawIdleScreen(dc, cx, cy, width, height);
        }
    }

    // ── Idle (setup) screen ───────────────────────────────────────────────────
    private function _drawIdleScreen(
        dc as Graphics.Dc,
        cx as Number, cy as Number,
        width as Number, height as Number) as Void {

        // App title
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 30, Graphics.FONT_SMALL, "Smart Alarm", Graphics.TEXT_JUSTIFY_CENTER);

        // Wake time label
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 55, Graphics.FONT_SMALL, "Wake Time", Graphics.TEXT_JUSTIFY_CENTER);

        // Wake time value
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 25, Graphics.FONT_NUMBER_MEDIUM,
            _alarmMgr.formatTargetTime(), Graphics.TEXT_JUSTIFY_CENTER);

        // Window label
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 30, Graphics.FONT_SMALL, "Window", Graphics.TEXT_JUSTIFY_CENTER);

        // Window value
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 55, Graphics.FONT_SMALL,
            _alarmMgr.windowMinutes + " min", Graphics.TEXT_JUSTIFY_CENTER);

        // Hint
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - 40, Graphics.FONT_TINY,
            "Press menu to configure", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Monitoring screen ─────────────────────────────────────────────────────
    private function _drawMonitoringScreen(
        dc as Graphics.Dc,
        cx as Number, cy as Number,
        width as Number, height as Number) as Void {

        // Pulsing dot indicator (simple green dot)
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, 35, 8);

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 50, Graphics.FONT_TINY, "Monitoring", Graphics.TEXT_JUSTIFY_CENTER);

        // Wake time
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 55, Graphics.FONT_SMALL, "Wake Time", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 25, Graphics.FONT_NUMBER_MEDIUM,
            _alarmMgr.formatTargetTime(), Graphics.TEXT_JUSTIFY_CENTER);

        // Window
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 30, Graphics.FONT_SMALL, "Window", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 55, Graphics.FONT_SMALL,
            _alarmMgr.windowMinutes + " min", Graphics.TEXT_JUSTIFY_CENTER);

        // Current time small
        var clk = System.getClockTime();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - 40, Graphics.FONT_TINY,
            clk.hour.format("%02d") + ":" + clk.min.format("%02d"),
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Alarm fired screen ────────────────────────────────────────────────────
    private function _drawFiredScreen(
        dc as Graphics.Dc,
        cx as Number, cy as Number,
        width as Number, height as Number) as Void {

        // Wake icon (simple circle + rays)
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, 50, 18);
        // Rays
        for (var i = 0; i < 8; i++) {
            var angle = (i * 45) * Math.PI / 180.0;
            var x1 = (cx + 24 * Math.cos(angle)).toNumber();
            var y1 = (50 + 24 * Math.sin(angle)).toNumber();
            var x2 = (cx + 32 * Math.cos(angle)).toNumber();
            var y2 = (50 + 32 * Math.sin(angle)).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 20, Graphics.FONT_MEDIUM, "Good morning!", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 20, Graphics.FONT_SMALL, "Alarm fired at", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 50, Graphics.FONT_NUMBER_MEDIUM,
            _alarmMgr.firedTime, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - 40, Graphics.FONT_TINY,
            "Press back to dismiss", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
