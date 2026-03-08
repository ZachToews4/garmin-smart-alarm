// SmartAlarmApp.mc
// Entry point for the Smart Alarm watchApp

import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background)
class SmartAlarmApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called when the app starts
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when the app stops.
    // If the alarm is actively running, hand off to the background service
    // instead of killing everything. The background will keep monitoring
    // and fire the alarm even while the app is closed.
    function onStop(state as Dictionary?) as Void {
        var mgr = AlarmManager.getInstance();
        if (mgr.isRunning) {
            mgr.suspendForeground();  // stops live sensors/timers; background takes over
        } else {
            mgr.stop();  // full stop — clears Storage and cancels background event
        }
    }

    // Register the background service delegate.
    // The system calls this to get the background process class.
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new AlarmBackground()];
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
