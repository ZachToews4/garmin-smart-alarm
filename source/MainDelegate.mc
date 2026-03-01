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

    // Menu button → show main menu
    function onMenu() as Boolean {
        WatchUi.pushView(
            new WatchUi.Menu2({:title => "Smart Alarm"}),
            new MainMenuDelegate(),
            WatchUi.SLIDE_UP
        );
        return true;
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
