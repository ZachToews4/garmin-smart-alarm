// TimePickerView.mc
// Native Garmin Picker for selecting wake time (hour + minute).

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

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
            :text  => _values[index].format(_format),
            :color => selected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            :font  => Graphics.FONT_NUMBER_HOT,
            :locX  => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY  => WatchUi.LAYOUT_VALIGN_CENTER
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
        var alarmMgr = AlarmManager.getInstance();

        var hours = [] as Array<Number>;
        for (var i = 0; i < 24; i++) { hours.add(i); }

        var minutes = [] as Array<Number>;
        for (var i = 0; i < 60; i += 5) { minutes.add(i); }

        var title = new WatchUi.Text({
            :text  => "Wake Time",
            :color => Graphics.COLOR_WHITE,
            :font  => Graphics.FONT_SMALL,
            :locX  => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY  => WatchUi.LAYOUT_VALIGN_BOTTOM
        });

        var separator = new WatchUi.Text({
            :text  => ":",
            :color => Graphics.COLOR_WHITE,
            :font  => Graphics.FONT_NUMBER_HOT,
            :locX  => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY  => WatchUi.LAYOUT_VALIGN_CENTER
        });

        // Default to currently configured wake time (persisted), or 6:30 AM
        var defaultHour   = 6;
        var defaultMinIdx = 6;  // index of 30 in the 5-min list
        if (alarmMgr.wakeTimeSet) {
            defaultHour   = alarmMgr.targetMinutes / 60;
            var curMin    = alarmMgr.targetMinutes % 60;
            // Round down to nearest 5-min slot
            defaultMinIdx = curMin / 5;
        }

        Picker.initialize({
            :title   => title,
            :pattern => [
                new TimePickerFactory(hours, "%02d"),
                separator,
                new TimePickerFactory(minutes, "%02d")
            ],
            :defaults => [defaultHour, 0, defaultMinIdx]
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
        // Use the setter so the new time is persisted immediately
        _alarmMgr.setWakeTime(h, m);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
