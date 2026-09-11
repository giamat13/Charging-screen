import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Background;
import Toybox.Application.Storage;

(:background)
class Charging_screenApp extends Application.AppBase {

    // שומר רפרנס ל-View כדי שהתפריט יוכל לקרוא ל-resetStats()
    private var mView as Charging_screenView?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        if (Storage.getValue("installTime") == null) {
            Storage.setValue("installTime", Time.now().value());
        }

        var bgEnabled = Storage.getValue("bgMonitoringEnabled") as Boolean?;
        if (bgEnabled == null || bgEnabled) {
            Background.registerForTemporalEvent(new Time.Duration(ChargeStats.BACKGROUND_INTERVAL_SECONDS));
        }
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        mView = new Charging_screenView();
        return [ mView as Charging_screenView, new Charging_screenDelegate(mView as Charging_screenView) ];
    }

    // Lets the OS wake this app briefly and periodically to check for charging sessions
    // that happen while the app itself isn't open (see Charging_screenServiceDelegate).
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new Charging_screenServiceDelegate() ];
    }

}

function getApp() as Charging_screenApp {
    return Application.getApp() as Charging_screenApp;
}
