import Toybox.Lang;
import Toybox.WatchUi;

// Generic swipe/next-page handling for the secondary screens (Details, History,
// Battery 24h), replacing a near-identical delegate per screen. Constructed with what the
// *next* page is (null if this is the last one in the chain) - swiping back always just pops.
class Charging_screenPageDelegate extends WatchUi.BehaviorDelegate {

    private var mNextView as WatchUi.View?;
    private var mNextDelegate as WatchUi.InputDelegate?;

    function initialize(nextView as WatchUi.View?, nextDelegate as WatchUi.InputDelegate?) {
        BehaviorDelegate.initialize();
        mNextView = nextView;
        mNextDelegate = nextDelegate;
    }

    function onNextPage() as Boolean {
        if (mNextView == null) {
            return false;
        }
        WatchUi.pushView(mNextView as WatchUi.View, mNextDelegate, WatchUi.SLIDE_LEFT);
        return true;
    }

    function onPreviousPage() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

}

// Single place that knows the secondary-screen order (Details -> History -> Battery 24h),
// used both by swipe navigation and by the menu, so there's one source of truth for it.

function pushBatteryGraph() as Void {
    var view = new Charging_screenBatteryGraphView();
    WatchUi.pushView(view, new Charging_screenBatteryGraphDelegate(view), WatchUi.SLIDE_LEFT);
}

function pushHistory() as Void {
    var graphView = new Charging_screenBatteryGraphView();
    var afterHistory = new Charging_screenPageDelegate(graphView, new Charging_screenBatteryGraphDelegate(graphView));
    WatchUi.pushView(new Charging_screenHistoryView(), afterHistory, WatchUi.SLIDE_LEFT);
}

function pushDetails() as Void {
    var graphView = new Charging_screenBatteryGraphView();
    var afterHistory = new Charging_screenPageDelegate(graphView, new Charging_screenBatteryGraphDelegate(graphView));
    var afterDetails = new Charging_screenPageDelegate(new Charging_screenHistoryView(), afterHistory);
    WatchUi.pushView(new Charging_screenDetailsView(), afterDetails, WatchUi.SLIDE_LEFT);
}
