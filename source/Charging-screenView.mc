import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Timer;
import Toybox.Lang;

// Application that runs only in the foreground (not in background). Enters it during charging,
// and measures charging rate: percentage per minute, minutes per percent, and estimated time to 100%.
class Charging_screenView extends WatchUi.View {

    private var mTimer as Timer.Timer?;

    // Measurement start values
    private var mStartTimeMs as Number?;
    private var mStartBattery as Float?;

    // Last measurement values
    private var mLastBattery as Float?;
    private var mIsCharging as Boolean = false;

    // Seconds between each measurement update
    private const UPDATE_INTERVAL_MS = 15000;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        // No need for fixed layout from Rez - everything is drawn manually in onUpdate
    }

    // Starts/resets the measurement start point
    function resetStats() as Void {
        var stats = System.getSystemStats();
        mStartTimeMs = System.getTimer();
        mStartBattery = stats.battery;
        mLastBattery = stats.battery;
        mIsCharging = stats.charging;
        WatchUi.requestUpdate();
    }

    // Called when this View is brought to the foreground.
    function onShow() as Void {
        resetStats();

        mTimer = new Timer.Timer();
        mTimer.start(method(:onTimerTick), UPDATE_INTERVAL_MS, true);
    }

    function onTimerTick() as Void {
        var stats = System.getSystemStats();
        mLastBattery = stats.battery;
        mIsCharging = stats.charging;
        WatchUi.requestUpdate();
    }

    // Called when this View is removed from the screen - stops the timer
    // because the application is not supposed to run in the background.
    function onHide() as Void {
        if (mTimer != null) {
            mTimer.stop();
            mTimer = null;
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        if (mLastBattery == null || mStartBattery == null || mStartTimeMs == null) {
            dc.drawText(centerX, height / 2, Graphics.FONT_SMALL, "Loading...", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (!mIsCharging) {
            dc.drawText(centerX, height / 2 - 20, Graphics.FONT_MEDIUM, "Not charging", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(centerX, height / 2 + 20, Graphics.FONT_XTINY, "Connect watch to charger", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var elapsedMs = System.getTimer() - (mStartTimeMs as Number);
        var elapsedMin = elapsedMs / 60000.0;
        var deltaPercent = (mLastBattery as Float) - (mStartBattery as Float);

        // Exact font heights from the device
        var bigH   = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);
        var smallH = dc.getFontHeight(Graphics.FONT_TINY);
        var tinyH  = dc.getFontHeight(Graphics.FONT_XTINY);

        if (elapsedMin < 0.5 || deltaPercent <= 0) {
            // 3 rows: big%, calculating, measured — center the block
            var totalH = bigH + tinyH + tinyH;
            var y = (height - totalH) / 2;

            dc.drawText(centerX, y, Graphics.FONT_NUMBER_MEDIUM, (mLastBattery as Float).format("%.0f") + "%", Graphics.TEXT_JUSTIFY_CENTER);
            y += bigH;
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Calculating charging rate...", Graphics.TEXT_JUSTIFY_CENTER);
            y += tinyH;
            dc.drawText(centerX, y, Graphics.FONT_XTINY, "Measured " + elapsedMin.format("%.1f") + " min", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var percentPerMin = deltaPercent / elapsedMin;
        var minPerPercent = 1.0 / percentPerMin;
        var remainingPercent = 100.0 - (mLastBattery as Float);
        var minutesToFull = remainingPercent * minPerPercent;

        // 5 rows: big%, %/min, min/%, time, measured — center the block
        var totalH = bigH + smallH + smallH + smallH + tinyH;
        var y = (height - totalH) / 2;

        dc.drawText(centerX, y, Graphics.FONT_NUMBER_MEDIUM, (mLastBattery as Float).format("%.0f") + "%", Graphics.TEXT_JUSTIFY_CENTER);
        y += bigH;

        dc.drawText(centerX, y, Graphics.FONT_TINY, percentPerMin.format("%.2f") + "% per minute", Graphics.TEXT_JUSTIFY_CENTER);
        y += smallH;
        dc.drawText(centerX, y, Graphics.FONT_TINY, minPerPercent.format("%.1f") + " min per percent", Graphics.TEXT_JUSTIFY_CENTER);
        y += smallH;

        if (minutesToFull < 0 || minutesToFull > 1440) {
            dc.drawText(centerX, y, Graphics.FONT_TINY, "Time to 100%: unknown", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var totalMinutes = minutesToFull.toNumber();
            var hoursToFull = totalMinutes / 60;
            var minsToFull = totalMinutes % 60;
            dc.drawText(centerX, y, Graphics.FONT_TINY, "Time to 100%: " + hoursToFull + "h " + minsToFull + "m", Graphics.TEXT_JUSTIFY_CENTER);
        }
        y += smallH;

        dc.drawText(centerX, y, Graphics.FONT_XTINY, "Measured " + elapsedMin.format("%.0f") + " min (hold for menu to reset)", Graphics.TEXT_JUSTIFY_CENTER);
    }

}
