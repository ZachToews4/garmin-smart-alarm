// MainDelegate.mc
// Input handler for the main view.

import Toybox.Lang;
import Toybox.WatchUi;

class MainDelegate extends WatchUi.BehaviorDelegate {

    private var _view as MainView;
    private var _alarmMgr as AlarmManager;

    function initialize(view as MainView) {
        BehaviorDelegate.initialize();
        _view     = view;
        _alarmMgr = AlarmManager.getInstance();
    }

    // Menu button (long-press upper button) → show main menu
    function onMenu() as Boolean {
        _openMenu();
        return true;
    }

    // Upper button short press (Start) → show main menu
    function onSelect() as Boolean {
        _openMenu();
        return true;
    }

    // Tap anywhere on screen → show main menu
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        _openMenu();
        return true;
    }

    private function _openMenu() as Void {
        var menu = new WatchUi.Menu2({:title => "Smart Alarm"});
        menu.addItem(new WatchUi.MenuItem("Set Wake Time", null, :setWakeTime, {}));
        menu.addItem(new WatchUi.MenuItem("Set Window",    null, :setWindow,   {}));
        if (_alarmMgr.isRunning) {
            menu.addItem(new WatchUi.MenuItem("Cancel Alarm", null, :cancelAlarm, {}));
        } else {
            menu.addItem(new WatchUi.MenuItem("Start Alarm",  null, :startAlarm,  {}));
        }
        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_UP);
    }

    // Back / ESC — if alarm fired, reset; otherwise exit
    function onBack() as Boolean {
        if (_alarmMgr.alarmFired) {
            _alarmMgr.alarmFired = false;
            _alarmMgr.firedTime  = "";
            WatchUi.requestUpdate();
            return true;
        }
        return false;    // let the system handle (exit app)
    }
}
