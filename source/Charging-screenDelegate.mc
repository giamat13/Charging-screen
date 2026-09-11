import Toybox.Lang;
import Toybox.WatchUi;

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
        WatchUi.pushView(menu, new Charging_screenMenuDelegate(mView), WatchUi.SLIDE_UP);
        return true;
    }

    function onNextPage() as Boolean {
        WatchUi.pushView(new Charging_screenHistoryView(), new Charging_screenHistoryDelegate(), WatchUi.SLIDE_LEFT);
        return true;
    }

}
