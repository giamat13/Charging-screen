import Toybox.Lang;
import Toybox.WatchUi;

// Lets the user swipe/press back from the history screen to return to the charging screen.
class Charging_screenHistoryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
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
