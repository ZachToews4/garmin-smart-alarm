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

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :setWakeTime) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _pushTimePickerView();
        } else if (id == :setWindow) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            var winView = new WindowPickerView();
            WatchUi.pushView(winView, new WindowPickerDelegate(winView), WatchUi.SLIDE_UP);
        } else if (id == :setSnooze) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            var snzView = new SnoozePickerView();
            WatchUi.pushView(snzView, new SnoozePickerDelegate(snzView), WatchUi.SLIDE_UP);
        } else if (id == :startAlarm) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            if (_alarmMgr.wakeTimeSet) {
                _alarmMgr.start();
            } else {
                // No wake time set — take the user straight to the time picker
                // rather than failing silently.
                _pushTimePickerView();
            }
        } else if (id == :cancelAlarm) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _alarmMgr.stop();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    private function _pushTimePickerView() as Void {
        WatchUi.pushView(
            new TimePickerView(),
            new TimePickerDelegate(),
            WatchUi.SLIDE_UP
        );
    }
}
