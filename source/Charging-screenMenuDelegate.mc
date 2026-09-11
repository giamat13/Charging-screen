import Toybox.Lang;
import Toybox.WatchUi;

class Charging_screenMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :reset) {
            getApp().resetStats();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (item == :history) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            pushHistory();
        } else if (item == :batteryGraph) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            pushBatteryGraph();
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

}
