import Toybox.Lang;
import Toybox.WatchUi;

class Charging_screenMenuDelegate extends WatchUi.MenuInputDelegate {

    private var mView as Charging_screenView;

    function initialize(view as Charging_screenView) {
        MenuInputDelegate.initialize();
        mView = view;
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :reset) {
            mView.resetStats();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

}
