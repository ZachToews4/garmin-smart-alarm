// SnoozePickerView.mc
// Lets the user choose the snooze duration (5 / 10 / 15 min).

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//
// ─── View ────────────────────────────────────────────────────────────────────
//

class SnoozePickerView extends WatchUi.View {

    private var _options  as Array<Number> = [5, 10, 15] as Array<Number>;
    private var _selected as Number = 0;   // index into _options, default 5 min
    private var _alarmMgr as AlarmManager;

    function initialize() {
        View.initialize();
        _alarmMgr = AlarmManager.getInstance();
        // Pre-select the currently configured snooze duration
        for (var i = 0; i < _options.size(); i++) {
            if (_options[i] == _alarmMgr.snoozeMinutes) {
                _selected = i;
                break;
            }
        }
    }

    function getSelected() as Number      { return _selected; }
    function getOptions()  as Array<Number> { return _options; }

    function scrollUp()   as Void { if (_selected > 0)                    { _selected--; } }
    function scrollDown() as Void { if (_selected < _options.size() - 1)  { _selected++; } }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width  = dc.getWidth();
        var height = dc.getHeight();
        var cx     = width / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Title
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (height * 0.04).toNumber(),
            Graphics.FONT_TINY, "Snooze Duration", Graphics.TEXT_JUSTIFY_CENTER);

        // Draw options
        var startY = (height * 0.25).toNumber();
        var rowH   = (height * 0.14).toNumber();
        for (var i = 0; i < _options.size(); i++) {
            var y = startY + i * rowH;
            if (i == _selected) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
                dc.fillRectangle(10, y, width - 20, rowH - 2);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, y + 1, Graphics.FONT_SMALL,
                _options[i] + " min", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hint
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - (height * 0.22).toNumber(),
            Graphics.FONT_TINY, "Scroll  ·  Select", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

//
// ─── Delegate ────────────────────────────────────────────────────────────────
//

class SnoozePickerDelegate extends WatchUi.BehaviorDelegate {

    private var _alarmMgr as AlarmManager;
    private var _view     as SnoozePickerView;

    function initialize(view as SnoozePickerView) {
        BehaviorDelegate.initialize();
        _alarmMgr = AlarmManager.getInstance();
        _view     = view;
    }

    function onSelect() as Boolean {
        var idx  = _view.getSelected();
        var opts = _view.getOptions();
        _alarmMgr.setSnoozeMinutes(opts[idx]);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onNextPage() as Boolean {
        _view.scrollDown();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollUp();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
