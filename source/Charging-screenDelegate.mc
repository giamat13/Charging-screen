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
        WatchUi.pushView(menu, new Charging_screenMenuDelegate(mView), WatchUi.SLIDE_UP);
        return true;
    }

}
