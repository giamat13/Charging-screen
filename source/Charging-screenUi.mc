import Toybox.Graphics;
import Toybox.Lang;

// Shared look-and-feel for every screen: one palette, one page-dot indicator, one battery
// color rule - so the four screens (Main / Details / History / Battery graph) read as one
// app instead of four independently-styled views, and it's always obvious where you are in
// the swipe sequence.
module ChargingUi {

    // -- Palette -------------------------------------------------------------------------
    // Kept semantic (name says what it's for, not what color it is) so a screen never picks
    // a raw Graphics.COLOR_* directly and the palette can move in one place if it ever needs to.
    const BG = Graphics.COLOR_BLACK;
    const TEXT_PRIMARY = Graphics.COLOR_WHITE;
    const TEXT_SECONDARY = Graphics.COLOR_LT_GRAY;
    const TEXT_MUTED = Graphics.COLOR_DK_GRAY;

    const STATUS_GOOD = Graphics.COLOR_GREEN;
    const STATUS_GOOD_DIM = Graphics.COLOR_DK_GREEN;
    const STATUS_MID = Graphics.COLOR_YELLOW;
    const STATUS_BAD = Graphics.COLOR_RED;
    const STATUS_ALERT = Graphics.COLOR_ORANGE;

    // -- Page sequence, for the dot indicator ---------------------------------------------
    // Order matches the real swipe/menu flow: Main -> Details -> History -> Battery graph.
    const PAGE_MAIN = 0;
    const PAGE_DETAILS = 1;
    const PAGE_HISTORY = 2;
    const PAGE_GRAPH = 3;
    const PAGE_COUNT = 4;

    // Battery-level color: red when low, yellow mid, green when high/full. Single source of
    // truth so the icon, the big %, and any other battery-colored text always agree.
    function batteryColor(percent as Float) as Graphics.ColorType {
        if (percent >= 80) {
            return STATUS_GOOD;
        } else if (percent >= 30) {
            return STATUS_MID;
        }
        return STATUS_BAD;
    }

    // Small row of dots at the very top of every screen, current page filled in white, the
    // rest dim - a constant, glanceable "you are here" so swiping never feels disorienting.
    function drawPageDots(dc as Dc, width as Number, currentPage as Number) as Number {
        var radius = 2;
        var gap = 9;
        var totalW = (PAGE_COUNT - 1) * gap;
        var startX = width / 2 - totalW / 2;
        var y = 7;

        for (var i = 0; i < PAGE_COUNT; i += 1) {
            var x = startX + i * gap;
            if (i == currentPage) {
                dc.setColor(TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, radius);
            } else {
                dc.setColor(TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
                dc.drawCircle(x, y, radius);
            }
        }

        return y + radius;
    }

    // Standard screen header: page dots, then the screen title underneath. Returns the y to
    // continue drawing content from, so every screen's body starts at a consistent offset.
    function drawHeader(dc as Dc, width as Number, currentPage as Number, title as String) as Number {
        var dotsBottom = drawPageDots(dc, width, currentPage);
        var y = dotsBottom + 6;

        dc.setColor(TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, y, Graphics.FONT_SMALL, title, Graphics.TEXT_JUSTIFY_CENTER);

        return y + dc.getFontHeight(Graphics.FONT_SMALL);
    }

    // One-line hint pinned to the bottom edge (e.g. "Swipe for details", "Tap to change
    // range") - always the same size/color/position so users learn where to look for it.
    function drawFooterHint(dc as Dc, width as Number, height as Number, text as String) as Void {
        dc.setColor(TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height - dc.getFontHeight(Graphics.FONT_XTINY) - 4, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Shared "Nh Nm" duration formatter used anywhere a minute count becomes a headline.
    function formatDuration(totalMinutes as Float) as String {
        if (totalMinutes < 0 || totalMinutes > 1440) {
            return "unknown";
        }
        var t = totalMinutes.toNumber();
        return (t / 60) + "h " + (t % 60) + "m";
    }

}
