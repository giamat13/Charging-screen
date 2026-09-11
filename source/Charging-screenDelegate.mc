import Toybox.Lang;
import Toybox.WatchUi;

class Charging_screenDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        var menu = new WatchUi.Menu();
        menu.setTitle("Menu");
        menu.addItem("Reset measurement", :reset);
        menu.addItem("Charge history", :history);
        menu.addItem("Battery 24h", :batteryGraph);
        WatchUi.pushView(menu, new Charging_screenMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // While charging, the next page is the rate/health Details screen; otherwise there's no
    // active session to detail, so skip straight to History.
    function onNextPage() as Boolean {
        if (getApp().mIsCharging) {
            pushDetails();
        } else {
            pushHistory();
        }
        return true;
    }

}
