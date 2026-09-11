import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Background;
import Toybox.Application;
import Toybox.Application.Storage;

// Runs at most once an hour (registered by the app, see Charging_screenApp), so charging
// sessions are still captured for the health trend even when the app isn't open to watch
// them. Battery-efficient by construction: the OS wakes this briefly on its own schedule
// (no polling loop), the work here is a couple of Storage reads/writes, and it calls
// Background.exit() immediately once done so the process doesn't linger.
(:background)
class Charging_screenServiceDelegate extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        try {
            var stats = System.getSystemStats();
            var wasCharging = Storage.getValue("bgLastCharging") as Boolean?;
            wasCharging = (wasCharging == null) ? false : wasCharging;

            if (stats.charging && !wasCharging) {
                // Charging just started, as far as we can tell at hourly resolution.
                Storage.setValue("bgSessionStart", {
                    "time" => Time.now().value(),
                    "battery" => stats.battery,
                });
            } else if (!stats.charging && wasCharging) {
                var start = Storage.getValue("bgSessionStart") as Dictionary?;
                if (start != null) {
                    var elapsedMin = (Time.now().value() - (start["time"] as Number)) / 60.0;
                    var deltaPercent = (stats.battery as Float) - (start["battery"] as Float);
                    ChargeStats.recordSession(deltaPercent, elapsedMin);
                }
                Storage.deleteValue("bgSessionStart");
            }

            ChargeStats.recordDrainSample(stats.battery as Float, stats.charging);
        } catch (e instanceof Application.ObjectStoreAccessException) {
            // Storage isn't reachable from a background process on this device/firmware
            // (pre ConnectIQ 3.2.0) - nothing safe to record this tick.
        }
        Background.exit(null);
    }

}
