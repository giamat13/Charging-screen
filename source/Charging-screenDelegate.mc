import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;

class Charging_screenDelegate extends WatchUi.BehaviorDelegate {

    private var mView as Charging_screenView;

    function initialize(view as Charging_screenView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onMenu() as Boolean {
        var menu = new WatchUi.Menu();
        menu.setTitle("Menu");
        menu.addItem("Reset measurement", :reset);
        menu.addItem("Charge history", :history);
        menu.addItem("Battery 24h", :batteryGraph);

        var bgEnabled = Storage.getValue("bgMonitoringEnabled") as Boolean?;
        bgEnabled = (bgEnabled == null) ? true : bgEnabled;
        menu.addItem(bgEnabled ? "Background check: On" : "Background check: Off", :toggleBackground);

        WatchUi.pushView(menu, new Charging_screenMenuDelegate(mView), WatchUi.SLIDE_UP);
        return true;
    }

    function onNextPage() as Boolean {
        WatchUi.pushView(new Charging_screenHistoryView(), new Charging_screenHistoryDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

}
