// MainMenuDelegate.mc
// Handles the main menu (set wake time, set window, start/cancel).

import Toybox.Lang;
import Toybox.WatchUi;

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _alarmMgr as AlarmManager;

    function initialize() {
        Menu2InputDelegate.initialize();
        _alarmMgr = AlarmManager.getInstance();
    }

    function onOpen() as Void {
        var menu = WatchUi.getCurrentView()[0] as WatchUi.Menu2;
        menu.addItem(new WatchUi.MenuItem("Set Wake Time",   null, :setWakeTime,   {}));
        menu.addItem(new WatchUi.MenuItem("Set Window",      null, :setWindow,     {}));
        if (_alarmMgr.isRunning) {
            menu.addItem(new WatchUi.MenuItem("Cancel Alarm", null, :cancelAlarm,  {}));
        } else {
            menu.addItem(new WatchUi.MenuItem("Start Alarm",  null, :startAlarm,   {}));
        }
    }

    function onSelect(item as WatchUi.MenuItem) as Boolean {
        var id = item.getId();

        if (id == :setWakeTime) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _pushTimePickerView();
        } else if (id == :setWindow) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.pushView(
                new WindowPickerView(),
                new WindowPickerDelegate(),
                WatchUi.SLIDE_UP
            );
        } else if (id == :startAlarm) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            if (_alarmMgr.wakeTimeSet) {
                _alarmMgr.start();
            }
        } else if (id == :cancelAlarm) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _alarmMgr.stop();
        }

        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    // Push a simple time-picker (hour + minute pickers chained).
    private function _pushTimePickerView() as Void {
        WatchUi.pushView(
            new TimePickerView(),
            new TimePickerDelegate(),
            WatchUi.SLIDE_UP
        );
    }
}
