// WindowPickerView.mc
// Lets the user choose the smart-alarm window (10/20/30/45/60 min).

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//
// ─── View ────────────────────────────────────────────────────────────────────
//

class WindowPickerView extends WatchUi.View {

    private var _options  as Array<Number> = [10, 20, 30, 45, 60] as Array<Number>;
    private var _selected as Number = 1;    // index into _options, default 20 min
    private var _alarmMgr as AlarmManager;

    function initialize() {
        View.initialize();
        _alarmMgr = AlarmManager.getInstance();
        // Pre-select the currently configured window
        for (var i = 0; i < _options.size(); i++) {
            if (_options[i] == _alarmMgr.windowMinutes) {
                _selected = i;
                break;
            }
        }
    }

    function getSelected() as Number { return _selected; }
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
        dc.drawText(cx, 25, Graphics.FONT_SMALL, "Wake Window", Graphics.TEXT_JUSTIFY_CENTER);

        // Draw options
        var startY = 75;
        var rowH   = 42;
        for (var i = 0; i < _options.size(); i++) {
            var y = startY + i * rowH;
            if (i == _selected) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
                dc.fillRectangle(10, y - 2, width - 20, rowH - 4);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, y + 5, Graphics.FONT_SMALL,
                _options[i] + " min", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - 30, Graphics.FONT_TINY,
            "Up/Down scroll • Select confirms", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

//
// ─── Delegate ────────────────────────────────────────────────────────────────
//

class WindowPickerDelegate extends WatchUi.BehaviorDelegate {

    private var _alarmMgr as AlarmManager;

    function initialize() {
        BehaviorDelegate.initialize();
        _alarmMgr = AlarmManager.getInstance();
    }

    function onSelect() as Boolean {
        var view     = WatchUi.getCurrentView()[0] as WindowPickerView;
        var idx      = view.getSelected();
        var opts     = view.getOptions();
        _alarmMgr.windowMinutes = opts[idx];
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onNextPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as WindowPickerView;
        view.scrollDown();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        var view = WatchUi.getCurrentView()[0] as WindowPickerView;
        view.scrollUp();
        WatchUi.requestUpdate();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
