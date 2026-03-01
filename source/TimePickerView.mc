// TimePickerView.mc
// A simple two-step number picker for hour then minute.
// Step 1: pick hour (0-23)
// Step 2: pick minute (0, 5, 10, … 55)

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//
// ─── Shared state between hour/minute pickers ───────────────────────────────
//

var gPickedHour   as Number = 6;
var gPickedMinute as Number = 30;

//
// ─── TimePickerView ──────────────────────────────────────────────────────────
//

class TimePickerView extends WatchUi.NumberPickerView {

    function initialize() {
        // Number picker: 0-23 for hour
        NumberPickerView.initialize(
            WatchUi.NUMBER_PICKER_TIME,
            {
                :hour   => gPickedHour,
                :minute => gPickedMinute
            }
        );
    }
}

//
// ─── TimePickerDelegate ──────────────────────────────────────────────────────
//

class TimePickerDelegate extends WatchUi.NumberPickerDelegate {

    private var _alarmMgr as AlarmManager;

    function initialize() {
        NumberPickerDelegate.initialize();
        _alarmMgr = AlarmManager.getInstance();
    }

    function onNumberPicked(number as Dictionary) as Boolean {
        var h = number[:hour]   as Number;
        var m = number[:minute] as Number;

        gPickedHour   = h;
        gPickedMinute = m;

        _alarmMgr.targetMinutes = h * 60 + m;
        _alarmMgr.wakeTimeSet   = true;

        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
