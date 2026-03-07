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
        AlarmManager.getInstance().stop();
    }

    // Return the initial view
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new MainView();
        var delegate = new MainDelegate(view);
        return [view, delegate];
    }
}

function getApp() as SmartAlarmApp {
    return Application.getApp() as SmartAlarmApp;
}
