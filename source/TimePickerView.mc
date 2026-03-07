// TimePickerView.mc
// Uses WatchUi.TimePicker for native time selection on Venu 2.

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//
// ─── Shared state ────────────────────────────────────────────────────────────
//

var gPickedHour   as Number = 6;
var gPickedMinute as Number = 30;

//
// ─── TimePickerFactory ───────────────────────────────────────────────────────
//

class TimePickerFactory extends WatchUi.PickerFactory {
    private var _values as Array<Number>;
    private var _format as String;

    function initialize(values as Array<Number>, format as String) {
        PickerFactory.initialize();
        _values = values;
        _format = format;
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable? {
        return new WatchUi.Text({
            :text => _values[index].format(_format),
            :color => selected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            :font => Graphics.FONT_NUMBER_HOT,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    function getSize() as Number {
        return _values.size();
    }

    function getValue(index as Number) as Object? {
        return _values[index];
    }
}

//
// ─── TimePickerView ──────────────────────────────────────────────────────────
//

class TimePickerView extends WatchUi.Picker {

    function initialize() {
        var hours = [] as Array<Number>;
        for (var i = 0; i < 24; i++) { hours.add(i); }

        var minutes = [] as Array<Number>;
        for (var i = 0; i < 60; i += 5) { minutes.add(i); }

        var title = new WatchUi.Text({
            :text => "Wake Time",
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_SMALL,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });

        var separator = new WatchUi.Text({
            :text => ":",
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_HOT,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });

        Picker.initialize({
            :title => title,
            :pattern => [
                new TimePickerFactory(hours, "%02d"),
                separator,
                new TimePickerFactory(minutes, "%02d")
            ],
            :defaults => [gPickedHour, 0, gPickedMinute / 5]
        });
    }
}

//
// ─── TimePickerDelegate ──────────────────────────────────────────────────────
//

class TimePickerDelegate extends WatchUi.PickerDelegate {

    private var _alarmMgr as AlarmManager;

    function initialize() {
        PickerDelegate.initialize();
        _alarmMgr = AlarmManager.getInstance();
    }

    function onAccept(values as Array) as Boolean {
        var h = values[0] as Number;
        var m = values[2] as Number;

        gPickedHour   = h;
        gPickedMinute = m;

        _alarmMgr.targetMinutes = h * 60 + m;
        _alarmMgr.wakeTimeSet   = true;

        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
