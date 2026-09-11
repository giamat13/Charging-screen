import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Timer;
import Toybox.Time;
import Toybox.Background;
import Toybox.Application.Storage;

// Owns the live charging-session state and the polling timer, instead of the main View, so
// the numbers keep updating even while a secondary screen (Details/History/...) is pushed on
// top - pushing a view calls the underlying view's onHide(), which would otherwise stop a
// timer owned by that view.
(:background)
class Charging_screenApp extends Application.AppBase {

    private var mTimer as Timer.Timer?;

    // Measurement start values
    var mStartTimeMs as Number?;
    var mStartBattery as Float?;

    // Last measurement values
    var mLastBattery as Float?;
    var mIsCharging as Boolean = false;

    // Recent battery% samples for the session sparkline, oldest first. Downsampled in place
    // so it keeps covering the whole session (which can span hours) within a fixed budget.
    var mSamples as Array<Float> = [];
    private const MAX_SAMPLES = 60;

    // Average % per minute measured across previous completed sessions (Storage-backed),
    // used to show an estimate before the current session has enough data of its own.
    var mStoredAvgRate as Float?;

    // Consecutive ticks the session rate must stay below the average by ANOMALY_THRESHOLD_PCT
    // before flagging it, so a single noisy sample doesn't trigger a false "check your cable".
    var mSlowStreak as Number = 0;
    const ANOMALY_STREAK_THRESHOLD = 4;
    private const ANOMALY_THRESHOLD_PCT = -30.0;

    // Seconds between each measurement update while the app is in the foreground.
    private const UPDATE_INTERVAL_MS = 15000;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        if (Storage.getValue("installTime") == null) {
            Storage.setValue("installTime", Time.now().value());
        }

        applyBackgroundSchedule();

        resetStats();
        mTimer = new Timer.Timer();
        mTimer.start(method(:onTimerTick), UPDATE_INTERVAL_MS, true);
    }

    // Registers (or cancels) the background temporal event to match the "Background check"
    // / "Check interval" settings - configured from the Garmin Connect app on the phone
    // (resources/settings/properties.xml), not on the watch.
    private function applyBackgroundSchedule() as Void {
        if (ChargeStats.isBackgroundEnabled()) {
            Background.registerForTemporalEvent(new Time.Duration(ChargeStats.getIntervalSeconds()));
        } else {
            Background.deleteTemporalEvent();
        }
    }

    // Called when the user changes a setting from the Garmin Connect app on the phone.
    function onSettingsChanged() as Void {
        applyBackgroundSchedule();
        WatchUi.requestUpdate();
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        if (mTimer != null) {
            mTimer.stop();
            mTimer = null;
        }
    }

    // Starts/resets the measurement start point
    function resetStats() as Void {
        var stats = System.getSystemStats();
        mStartTimeMs = System.getTimer();
        mStartBattery = stats.battery;
        mLastBattery = stats.battery;
        mIsCharging = stats.charging;
        mSamples = [stats.battery as Float];
        mStoredAvgRate = Storage.getValue("avgPercentPerMin") as Float?;
        WatchUi.requestUpdate();
    }

    // Persists this session's result (via the shared ChargeStats module, also used by the
    // background check) then resets the measurement start point for the new (idle) state.
    private function finishSession() as Void {
        var elapsedMin = (System.getTimer() - (mStartTimeMs as Number)) / 60000.0;
        ChargeStats.recordSession(mStartBattery as Float, mLastBattery as Float, elapsedMin);
    }

    function onTimerTick() as Void {
        var stats = System.getSystemStats();
        var wasCharging = mIsCharging;
        mLastBattery = stats.battery;
        mIsCharging = stats.charging;

        if (wasCharging && !mIsCharging) {
            finishSession();
            resetStats();
        } else if (mIsCharging) {
            mSamples.add(stats.battery as Float);
            if (mSamples.size() > MAX_SAMPLES) {
                var downsampled = [] as Array<Float>;
                for (var i = 0; i < mSamples.size(); i += 2) {
                    downsampled.add(mSamples[i]);
                }
                mSamples = downsampled;
            }

            var elapsedMin = (System.getTimer() - (mStartTimeMs as Number)) / 60000.0;
            var deltaPercent = (stats.battery as Float) - (mStartBattery as Float);
            if (mStoredAvgRate != null && (mStoredAvgRate as Float) > 0 && elapsedMin >= 0.5 && deltaPercent > 0) {
                var rate = deltaPercent / elapsedMin;
                var diffPct = (rate - (mStoredAvgRate as Float)) / (mStoredAvgRate as Float) * 100.0;
                mSlowStreak = (diffPct <= ANOMALY_THRESHOLD_PCT) ? mSlowStreak + 1 : 0;
            } else {
                mSlowStreak = 0;
            }
        }

        WatchUi.requestUpdate();
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new Charging_screenView(), new Charging_screenDelegate() ];
    }

    // Lets the OS wake this app briefly and periodically to check for charging sessions
    // that happen while the app itself isn't open (see Charging_screenServiceDelegate).
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new Charging_screenServiceDelegate() ];
    }

}

function getApp() as Charging_screenApp {
    return Application.getApp() as Charging_screenApp;
}
