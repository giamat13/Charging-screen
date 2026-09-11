import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Background;
import Toybox.Application.Storage;

class Charging_screenMenuDelegate extends WatchUi.MenuInputDelegate {

    private var mView as Charging_screenView;

    function initialize(view as Charging_screenView) {
        MenuInputDelegate.initialize();
        mView = view;
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :reset) {
            mView.resetStats();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (item == :history) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.pushView(new Charging_screenHistoryView(), new Charging_screenHistoryDelegate(), WatchUi.SLIDE_LEFT);
        } else if (item == :batteryGraph) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.pushView(new Charging_screenBatteryGraphView(), new Charging_screenBatteryGraphDelegate(), WatchUi.SLIDE_LEFT);
        } else if (item == :toggleBackground) {
            var bgEnabled = Storage.getValue("bgMonitoringEnabled") as Boolean?;
            bgEnabled = (bgEnabled == null) ? true : bgEnabled;
            var newEnabled = !bgEnabled;
            Storage.setValue("bgMonitoringEnabled", newEnabled);
            if (newEnabled) {
                Background.registerForTemporalEvent(new Time.Duration(ChargeStats.BACKGROUND_INTERVAL_SECONDS));
            } else {
                Background.deleteTemporalEvent();
            }
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

}
