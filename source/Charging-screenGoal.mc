import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Application.Storage;

// A user-set charging goal ("get to X% within HH:MM from now"), configured entirely on the
// watch (see Charging-screenGoalPicker.mc / Charging-screenGoalKeypad.mc) rather than from
// the phone's Garmin Connect settings, since it's a one-off target you set right before
// plugging in, not a lasting preference.
//
// Entered as a duration from now (e.g. "01:00" means "in 1 hour", not "at 1am") and
// immediately converted to a fixed deadline (Time.now() + duration) at set() time - so
// "time remaining" stays correct without having to reason about today-vs-tomorrow, and
// formatGoalTime() can still show it back as an absolute clock time.
module ChargeGoal {

    function isSet() as Boolean {
        return Storage.getValue("goalPercent") != null && Storage.getValue("goalDeadline") != null;
    }

    function getPercent() as Number? {
        return Storage.getValue("goalPercent") as Number?;
    }

    function getDeadline() as Number? {
        return Storage.getValue("goalDeadline") as Number?;
    }

    function set(percent as Number, hoursFromNow as Number, minutesFromNow as Number) as Void {
        var deadline = Time.now().value() + hoursFromNow * 3600 + minutesFromNow * 60;
        Storage.setValue("goalPercent", percent);
        Storage.setValue("goalDeadline", deadline);
    }

    function clear() as Void {
        Storage.deleteValue("goalPercent");
        Storage.deleteValue("goalDeadline");
    }

    // Minutes from now until the goal's deadline - negative once the deadline has passed.
    function minutesUntilGoalTime() as Float {
        var deadline = getDeadline() as Number;
        return (deadline - Time.now().value()) / 60.0;
    }

    // The deadline as a local HH:MM clock time, for display.
    function formatGoalTime() as String {
        var info = Gregorian.info(new Time.Moment(getDeadline() as Number), Time.FORMAT_SHORT);
        return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }

}
