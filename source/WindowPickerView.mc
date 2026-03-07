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

        // Title  (FONT_TINY = 43px on Venu 2, y=18 → bottom 61)
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 18, Graphics.FONT_TINY, "Wake Window", Graphics.TEXT_JUSTIFY_CENTER);

        // Draw options  (5 rows × 50px = 250px, y=66..316)
        var startY = 66;
        var rowH   = 50;
        for (var i = 0; i < _options.size(); i++) {
            var y = startY + i * rowH;
            if (i == _selected) {
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
                dc.fillRectangle(10, y, width - 20, rowH - 2);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            }
            // Center text vertically within the row (rowH=50, FONT_SMALL=49px)
            dc.drawText(cx, y + 1, Graphics.FONT_SMALL,
                _options[i] + " min", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hint  (y=326, FONT_TINY=43px → bottom 369, within bezel)
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - 90, Graphics.FONT_TINY,
            "Scroll  ·  Select", Graphics.TEXT_JUSTIFY_CENTER);
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
