// MainDelegate.mc
// Input handler for the main view.

import Toybox.Lang;
import Toybox.WatchUi;

class MainDelegate extends WatchUi.BehaviorDelegate {

    private var _alarmMgr as AlarmManager;

    function initialize() {
        BehaviorDelegate.initialize();
        _alarmMgr = AlarmManager.getInstance();
    }

    // Upper button short press (Start) / menu button
    function onSelect() as Boolean {
        if (_alarmMgr.alarmFired) {
            _alarmMgr.snooze();   // snooze while alarm is firing
            return true;
        }
        _openMenu();
        return true;
    }

    // Long-press upper button
    function onMenu() as Boolean {
        if (_alarmMgr.alarmFired) {
            _alarmMgr.snooze();
            return true;
        }
        _openMenu();
        return true;
    }

    // Tap anywhere on screen
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        if (_alarmMgr.alarmFired) {
            _alarmMgr.snooze();   // easiest action while half-asleep
            return true;
        }
        _openMenu();
        return true;
    }

    private function _openMenu() as Void {
        var menu = new WatchUi.Menu2({:title => "Smart Alarm"});
        if (_alarmMgr.isRunning) {
            menu.addItem(new WatchUi.MenuItem("Cancel Alarm", null, :cancelAlarm, {}));
            menu.addItem(new WatchUi.MenuItem("Test Alarm",   null, :testAlarm,   {}));
        } else {
            menu.addItem(new WatchUi.MenuItem("Start Alarm",  null, :startAlarm,  {}));
        }
        menu.addItem(new WatchUi.MenuItem("Set Wake Time", null, :setWakeTime, {}));
        menu.addItem(new WatchUi.MenuItem("Set Window",    null, :setWindow,   {}));
        menu.addItem(new WatchUi.MenuItem("Set Snooze",    null, :setSnooze,   {}));
        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_UP);
    }

    // Back / ESC
    function onBack() as Boolean {
        if (_alarmMgr.alarmFired) {
            _alarmMgr.dismiss();
            return true;
        }
        if (_alarmMgr.snoozing) {
            // Cancel snooze entirely
            _alarmMgr.stop();
            return true;
        }
        if (_alarmMgr.isRunning) {
            // Block accidental exit while monitoring — use menu → Cancel Alarm to stop.
            // Returning true eats the back press without exiting the app.
            return true;
        }
        return false;    // let the system handle (exit app)
    }
}
