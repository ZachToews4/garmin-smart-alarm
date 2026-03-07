// TimePickerView.mc
// Native Garmin Picker for selecting wake time (hour + minute).
// Adapts layout for the device's 12h or 24h time format setting.

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//
// ─── TimePickerFactory ───────────────────────────────────────────────────────
// Scrollable column of numeric values.
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

    function getSize() as Number { return _values.size(); }

    function getValue(index as Number) as Object? { return _values[index]; }
}

//
// ─── AmPmPickerFactory ───────────────────────────────────────────────────────
// Two-item column for AM / PM selection (12h mode only).
//

class AmPmPickerFactory extends WatchUi.PickerFactory {
    private var _labels as Array<String> = ["AM", "PM"] as Array<String>;

    function initialize() { PickerFactory.initialize(); }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable? {
        return new WatchUi.Text({
            :text  => _labels[index],
            :color => selected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            :font  => Graphics.FONT_MEDIUM,
            :locX  => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY  => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    function getSize() as Number { return 2; }

    // Returns 0 for AM, 1 for PM
    function getValue(index as Number) as Object? { return index; }
}

//
// ─── TimePickerView ──────────────────────────────────────────────────────────
//

class TimePickerView extends WatchUi.Picker {

    function initialize() {
        var alarmMgr = AlarmManager.getInstance();

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

        // Default to the currently stored wake time, or 6:30 AM
        var storedHour = 6;
        var storedMin  = 30;
        if (alarmMgr.wakeTimeSet) {
            storedHour = alarmMgr.targetMinutes / 60;
            storedMin  = alarmMgr.targetMinutes % 60;
        }
        // Round down to nearest 5-min slot
        var defaultMinIdx = storedMin / 5;

        if (System.getDeviceSettings().is24Hour) {
            // ── 24-hour mode ─────────────────────────────────────────────────
            var hours = [] as Array<Number>;
            for (var i = 0; i < 24; i++) { hours.add(i); }

            Picker.initialize({
                :title   => title,
                :pattern => [
                    new TimePickerFactory(hours, "%02d"),
                    separator,
                    new TimePickerFactory(minutes, "%02d")
                ],
                :defaults => [storedHour, 0, defaultMinIdx]
            });
        } else {
            // ── 12-hour mode ─────────────────────────────────────────────────
            // Hours are displayed as 1-12; AM/PM is a separate column.
            var hours12 = [] as Array<Number>;
            for (var i = 1; i <= 12; i++) { hours12.add(i); }

            // Convert stored 24h hour to 12h display values
            var defaultAmPm  = (storedHour >= 12) ? 1 : 0;   // 0=AM, 1=PM
            var displayHour  = storedHour % 12;
            if (displayHour == 0) { displayHour = 12; }       // midnight/noon → 12
            var defaultHourIdx = displayHour - 1;              // index into [1..12]

            // Spacer between the minutes column and AM/PM column
            var spacer = new WatchUi.Text({
                :text  => " ",
                :color => Graphics.COLOR_TRANSPARENT,
                :font  => Graphics.FONT_SMALL,
                :locX  => WatchUi.LAYOUT_HALIGN_CENTER,
                :locY  => WatchUi.LAYOUT_VALIGN_CENTER
            });

            Picker.initialize({
                :title   => title,
                :pattern => [
                    new TimePickerFactory(hours12, "%d"),
                    separator,
                    new TimePickerFactory(minutes, "%02d"),
                    spacer,
                    new AmPmPickerFactory()
                ],
                :defaults => [defaultHourIdx, 0, defaultMinIdx, 0, defaultAmPm]
            });
        }
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
        var m = values[2] as Number;
        var h = 0;

        if (System.getDeviceSettings().is24Hour) {
            // 24h: values[0] = 0-23
            h = values[0] as Number;
        } else {
            // 12h: values[0] = 1-12, values[4] = 0 (AM) or 1 (PM)
            var hour12 = values[0] as Number;
            var ampm   = values[4] as Number;
            if (ampm == 0 && hour12 == 12) {
                h = 0;          // 12 AM → midnight (0)
            } else if (ampm == 1 && hour12 != 12) {
                h = hour12 + 12;  // PM and not noon → add 12
            } else {
                h = hour12;     // 12 PM (noon) stays 12; 1-11 AM stays as-is
            }
        }

        _alarmMgr.setWakeTime(h, m);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
