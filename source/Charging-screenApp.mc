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

    // When charging stops mid-session, System.getTimer() at the moment it stopped - null
    // while charging normally or fully idle. Session isn't actually ended until it's stayed
    // disconnected for DISCONNECT_GRACE_MS straight, so a cable that slips out for a few
    // seconds/minutes doesn't cut the session short.
    private var mDisconnectedAtMs as Number?;
    private const DISCONNECT_GRACE_MS = 5 * 60 * 1000;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        if (Storage.getValue("installTime") == null) {
            Storage.setValue("installTime", Time.now().value());
        }

        applyBackgroundSchedule(false);

        resetStats();
        mTimer = new Timer.Timer();
        mTimer.start(method(:onTimerTick), UPDATE_INTERVAL_MS, true);
    }

    // Registers (or cancels) the background temporal event to match the "Background check"
    // / "Check interval" settings - configured from the Garmin Connect app on the phone
    // (resources/settings/properties.xml), not on the watch.
    //
    // Temporal events can't be (re)registered less than 5 minutes after the last one fired -
    // and unlike a one-shot Moment, that restriction does NOT get cleared just because the app
    // restarted while using a recurring Duration (which is what getIntervalSeconds() gives us).
    // Re-registering unconditionally on every app open was throwing an uncaught
    // InvalidBackgroundTimeException whenever the app was reopened within that window, which
    // silently killed the background schedule - this is why logging looked like it wasn't
    // running. Only (re)register when actually needed: nothing registered yet, or the caller
    // (a settings change) explicitly wants to force it.
    private function applyBackgroundSchedule(forceReregister as Boolean) as Void {
        if (!ChargeStats.isBackgroundEnabled()) {
            Background.deleteTemporalEvent();
            return;
        }
        if (!forceReregister && Background.getTemporalEventRegisteredTime() != null) {
            return;
        }
        try {
            Background.registerForTemporalEvent(new Time.Duration(ChargeStats.getIntervalSeconds()));
        } catch (e instanceof Background.InvalidBackgroundTimeException) {
            // Too soon after the last background event fired; leave the previous
            // registration (if any) in place instead of crashing app startup.
        }
    }

    // Called when the user changes a setting from the Garmin Connect app on the phone.
    function onSettingsChanged() as Void {
        applyBackgroundSchedule(true);
        resetStats();
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
        if (DemoData.isEnabled()) {
            mStartTimeMs = System.getTimer() - (DemoData.ELAPSED_MIN * 60000).toNumber();
            mStartBattery = DemoData.START_BATTERY;
            mLastBattery = DemoData.BATTERY;
            mIsCharging = true;
            mSamples = DemoData.SAMPLES;
            mStoredAvgRate = DemoData.getValue("avgPercentPerMin") as Float?;
            WatchUi.requestUpdate();
            return;
        }

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
    // Also clears any charge goal - it was set for this session, so it shouldn't silently
    // carry over and apply to whatever charges next.
    private function finishSession() as Void {
        var elapsedMin = (System.getTimer() - (mStartTimeMs as Number)) / 60000.0;
        ChargeStats.recordSession(mStartBattery as Float, mLastBattery as Float, elapsedMin);
        ChargeGoal.clear();
    }

    function onTimerTick() as Void {
        if (DemoData.isEnabled()) {
            // Frozen scenario - don't drift the fixed demo numbers or finish the "session".
            WatchUi.requestUpdate();
            return;
        }

        var stats = System.getSystemStats();

        if (stats.charging) {
            // Charging (still, or again after a brief disconnect blip) - cancel any pending
            // disconnect and keep tracking the session exactly as before.
            mDisconnectedAtMs = null;
            mLastBattery = stats.battery;
            mIsCharging = true;

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
        } else if (mIsCharging) {
            // Not charging right now, but we were - could be a cable that slipped out by
            // accident. Don't end the session yet; only after DISCONNECT_GRACE_MS of staying
            // disconnected. Keep showing the session as-is in the meantime.
            if (mDisconnectedAtMs == null) {
                mDisconnectedAtMs = System.getTimer();
            } else if (System.getTimer() - (mDisconnectedAtMs as Number) >= DISCONNECT_GRACE_MS) {
                mLastBattery = stats.battery;
                mDisconnectedAtMs = null;
                finishSession();
                resetStats();
            }
        } else {
            // Genuinely idle - no session to protect.
            mLastBattery = stats.battery;
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
