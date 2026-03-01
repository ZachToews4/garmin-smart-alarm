// SmartAlarmApp.mc
// Entry point for the Smart Alarm watchApp

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SmartAlarmApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called when the app starts
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when the app stops — clean up sensors/timers here
    function onStop(state as Dictionary?) as Void {
        var alarmMgr = AlarmManager.getInstance();
        if (alarmMgr != null) {
            alarmMgr.stop();
        }
    }

    // Return the initial view
    function getInitialView() as Array<Views or InputDelegates>? {
        var view = new MainView();
        var delegate = new MainDelegate(view);
        return [view, delegate] as Array<Views or InputDelegates>;
    }
}

function getApp() as SmartAlarmApp {
    return Application.getApp() as SmartAlarmApp;
}
