import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class Charging_screenApp extends Application.AppBase {

    // שומר רפרנס ל-View כדי שהתפריט יוכל לקרוא ל-resetStats()
    private var mView as Charging_screenView?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        mView = new Charging_screenView();
        return [ mView as Charging_screenView, new Charging_screenDelegate(mView as Charging_screenView) ];
    }

}

function getApp() as Charging_screenApp {
    return Application.getApp() as Charging_screenApp;
}
