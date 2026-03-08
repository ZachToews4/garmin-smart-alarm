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
        // IMPORTANT: This method runs in BOTH foreground and background contexts
        // because SmartAlarmApp is (:background). AlarmManager and WatchUi are
        // foreground-only and CANNOT be referenced here at all.
        //
        // Logic: if KEY_RUNNING is false/absent → clean up storage + cancel
        // background event. If true → leave everything intact so AlarmBackground
        // can continue monitoring (or already has: background onStop fires AFTER
        // onTemporalEvent completes).
        //
        // In the foreground case where the user cancelled the alarm, AlarmManager.stop()
        // has already deleted KEY_RUNNING before onStop() is called, so we arrive
        // here with KEY_RUNNING = null → we do nothing extra (already clean).
        var running = Application.Storage.getValue(KEY_RUNNING);
        if (running == null || !(running as Boolean)) {
            Application.Storage.deleteValue(KEY_RUNNING);
            Application.Storage.deleteValue(KEY_SLEEP_ONSET);
            Application.Storage.deleteValue(KEY_ONSET_COUNT);
            Application.Storage.deleteValue(KEY_SNOOZE_MODE);
            Application.Storage.deleteValue(KEY_SNOOZE_TARGET);
            Background.deleteTemporalEvent();
        }
        // If running: leave Storage + temporal event intact — background continues.
    }

    // Register the background service delegate.
    // The system calls this to get the background process class.
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new AlarmBackground()];
    }

    // Return the initial view
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new MainView();
        var delegate = new MainDelegate();
        return [view, delegate];
    }
}
