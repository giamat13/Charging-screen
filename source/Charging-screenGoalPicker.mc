import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// A simple evenly-spaced number wheel for Picker (there's no built-in one in Toybox - see the
// SDK's own Picker sample, which defines the same kind of factory itself).
class ChargingNumberFactory extends WatchUi.PickerFactory {

    private var mStart as Number;
    private var mIncrement as Number;
    private var mCount as Number;
    private var mFormat as String;
    private var mFont as FontDefinition;

    function initialize(start as Number, stop as Number, increment as Number, options as Dictionary) {
        PickerFactory.initialize();
        mStart = start;
        mIncrement = increment;
        mCount = (stop - start) / increment + 1;

        var format = options.get(:format);
        mFormat = (format != null) ? format as String : "%d";

        var font = options.get(:font);
        mFont = (font != null) ? font as FontDefinition : Graphics.FONT_NUMBER_HOT;
    }

    function getSize() as Number {
        return mCount;
    }

    function getValue(index as Number) as Object? {
        return mStart + (index * mIncrement);
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable? {
        var value = getValue(index) as Number;
        return new WatchUi.Text({
            :text => value.format(mFormat),
            :color => ChargingUi.TEXT_PRIMARY,
            :font => mFont,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER,
        });
    }

}

// On-watch flow for setting a charge goal: percent picker, then an hour/minute time picker,
// entered from the menu (Charging_screenMenuDelegate). Two steps instead of one combined
// picker because Picker only supports one row of wheels sharing a single title.
function pushGoalPercentPicker() as Void {
    // No :format here - Monkey C's format() has no "%%" escape for a literal percent sign
    // (supported specifiers are d/i/e/E/f/o/u/x/X only), and passing one crashes the picker
    // on its first draw. The title already says "Goal %".
    var factory = new ChargingNumberFactory(5, 100, 5, { :font => Graphics.FONT_NUMBER_MEDIUM });
    var title = new WatchUi.Text({
        :text => "Goal %",
        :font => Graphics.FONT_TINY,
        :locX => WatchUi.LAYOUT_HALIGN_CENTER,
        :locY => WatchUi.LAYOUT_VALIGN_BOTTOM,
        :color => ChargingUi.TEXT_SECONDARY,
    });
    var picker = new WatchUi.Picker({
        :title => title,
        :pattern => [ factory ],
    });
    WatchUi.pushView(picker, new Charging_screenGoalPercentPickerDelegate(), WatchUi.SLIDE_UP);
}

class Charging_screenGoalPercentPickerDelegate extends WatchUi.PickerDelegate {

    function initialize() {
        PickerDelegate.initialize();
    }

    function onAccept(values as Array) as Boolean {
        var percent = values[0] as Number;
        WatchUi.popView(WatchUi.SLIDE_LEFT);
        // Duration-from-now entry (see Charging-screenGoalKeypad.mc), not a wheel - a grid of
        // digits is faster to hit than scrolling through up to 24/60 wheel values.
        pushGoalHourKeypad(percent);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

}
