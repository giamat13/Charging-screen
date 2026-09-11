import Toybox.Lang;
import Toybox.WatchUi;

// Lets the user swipe/press back from the history screen to return to the charging screen.
class Charging_screenHistoryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Boolean {
        WatchUi.pushView(new Charging_screenBatteryGraphView(), new Charging_screenBatteryGraphDelegate(), WatchUi.SLIDE_LEFT);
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
