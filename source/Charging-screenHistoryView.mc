import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application.Storage;

// Shows the last few completed charging sessions (swipe/next-page from the main screen).
class Charging_screenHistoryView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var centerX = width / 2;
        var rowH = dc.getFontHeight(Graphics.FONT_TINY);

        var history = Storage.getValue("chargeHistory") as Array?;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 10, Graphics.FONT_SMALL, "Charge History", Graphics.TEXT_JUSTIFY_CENTER);

        if (history == null || history.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, 10 + rowH * 3, Graphics.FONT_XTINY, "No completed sessions yet", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var y = 10 + rowH + 10;
        // Most recent first
        for (var i = history.size() - 1; i >= 0; i -= 1) {
            var entry = history[i] as Dictionary;
            var info = Gregorian.info(new Time.Moment(entry["endTime"] as Number), Time.FORMAT_SHORT);
            var dateStr = info.month.format("%02d") + "/" + info.day.format("%02d") + " " + info.hour.format("%02d") + ":" + info.min.format("%02d");

            var durationMin = (entry["durationMin"] as Float).toNumber();
            var durationStr = (durationMin / 60) + "h" + (durationMin % 60).format("%02d") + "m";

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, y, Graphics.FONT_XTINY,
                dateStr + "  " + durationStr + "  +" + (entry["percentGained"] as Float).format("%.0f") + "%",
                Graphics.TEXT_JUSTIFY_CENTER);
            y += rowH;
        }
    }

}
