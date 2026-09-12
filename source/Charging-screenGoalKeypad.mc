import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// Digit-grid keypad for entering the goal's "in HH:MM from now" duration - faster than
// scrolling a wheel through up to 24/60 values one at a time. Two screens in sequence (hours,
// then minutes), since one keypad only builds one number.
const KEYPAD_ROWS = [
    ["1", "2", "3"],
    ["4", "5", "6"],
    ["7", "8", "9"],
    ["<", "0", ">"], // "<" = backspace, ">" = done
] as Array<Array<String> >;

class Charging_screenGoalKeypadView extends WatchUi.View {

    private var mTitle as String;
    private var mMaxValue as Number;
    private var mEntry as String = "";
    var mCursorRow as Number = 3;
    var mCursorCol as Number = 2; // start on done, since a short/blank entry (0) is a valid answer

    private var mCellW as Number = 0;
    private var mCellH as Number = 0;
    private var mGridLeft as Number = 0;
    private var mGridTop as Number = 0;

    function initialize(title as String, maxValue as Number) {
        View.initialize();
        mTitle = title;
        mMaxValue = maxValue;
    }

    function onLayout(dc as Dc) as Void {
    }

    function getValue() as Number {
        if (mEntry.length() == 0) {
            return 0;
        }
        var value = mEntry.toNumber() as Number;
        return (value > mMaxValue) ? mMaxValue : value;
    }

    function isDone(row as Number, col as Number) as Boolean {
        return KEYPAD_ROWS[row][col].equals(">");
    }

    function pressKey(row as Number, col as Number) as Void {
        var key = KEYPAD_ROWS[row][col];
        if (key.equals("<")) {
            if (mEntry.length() > 0) {
                mEntry = mEntry.substring(0, mEntry.length() - 1);
            }
        } else if (!key.equals(">") && mEntry.length() < 2) {
            mEntry += key;
        }
        WatchUi.requestUpdate();
    }

    function moveCursor(delta as Number) as Void {
        var cols = KEYPAD_ROWS[0].size();
        var total = KEYPAD_ROWS.size() * cols;
        var flat = ((mCursorRow * cols + mCursorCol + delta) % total + total) % total;
        mCursorRow = flat / cols;
        mCursorCol = flat % cols;
        WatchUi.requestUpdate();
    }

    // Returns [row, col] of the cell under (x, y), or null if outside the grid - used to let
    // touch devices tap a key directly instead of moving the cursor to it first.
    function hitTest(x as Number, y as Number) as Array<Number>? {
        var cols = KEYPAD_ROWS[0].size();
        if (mCellW == 0 || x < mGridLeft || x >= mGridLeft + mCellW * cols || y < mGridTop) {
            return null;
        }
        var col = (x - mGridLeft) / mCellW;
        var row = (y - mGridTop) / mCellH;
        if (row < 0 || row >= KEYPAD_ROWS.size()) {
            return null;
        }
        return [row, col];
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(ChargingUi.TEXT_PRIMARY, ChargingUi.BG);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;
        var titleH = dc.getFontHeight(Graphics.FONT_TINY);
        var entryH = dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM);

        dc.setColor(ChargingUi.TEXT_SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 6, Graphics.FONT_TINY, mTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var displayText = (mEntry.length() == 0) ? "--" : mEntry;
        dc.setColor(ChargingUi.TEXT_PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 6 + titleH + 2, Graphics.FONT_NUMBER_MEDIUM, displayText, Graphics.TEXT_JUSTIFY_CENTER);

        var rows = KEYPAD_ROWS.size();
        var cols = KEYPAD_ROWS[0].size();
        var gridTop = 6 + titleH + 2 + entryH + 8;
        mCellH = (height - 6 - gridTop) / rows;
        mCellW = (width * 3 / 4) / cols;
        mGridLeft = centerX - (mCellW * cols) / 2;
        mGridTop = gridTop;

        for (var r = 0; r < rows; r += 1) {
            for (var c = 0; c < cols; c += 1) {
                var key = KEYPAD_ROWS[r][c];
                var cellLeft = mGridLeft + c * mCellW;
                var cellTop = mGridTop + r * mCellH;
                var cellCenterX = cellLeft + mCellW / 2;
                var cellCenterY = cellTop + mCellH / 2;

                if (r == mCursorRow && c == mCursorCol) {
                    dc.setColor(ChargingUi.TEXT_MUTED, Graphics.COLOR_TRANSPARENT);
                    dc.fillRoundedRectangle(cellLeft + 2, cellTop + 2, mCellW - 4, mCellH - 4, 6);
                }

                var label = key;
                var color = ChargingUi.TEXT_PRIMARY;
                if (key.equals("<")) {
                    color = ChargingUi.TEXT_SECONDARY;
                } else if (key.equals(">")) {
                    label = "OK";
                    color = ChargingUi.STATUS_GOOD;
                }
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cellCenterX, cellCenterY, Graphics.FONT_MEDIUM, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

}

// Shared input handling (touch tap, button cursor movement, select) for both keypad steps -
// subclasses only need to say what happens once a value is confirmed (the ">" key).
class Charging_screenGoalKeypadDelegate extends WatchUi.BehaviorDelegate {

    protected var mView as Charging_screenGoalKeypadView;

    function initialize(view as Charging_screenGoalKeypadView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onSelect() as Boolean {
        activate(mView.mCursorRow, mView.mCursorCol);
        return true;
    }

    function onTap(evt as ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var hit = mView.hitTest(coords[0], coords[1]);
        if (hit != null) {
            activate(hit[0], hit[1]);
        }
        return true;
    }

    function onNextPage() as Boolean {
        mView.moveCursor(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        mView.moveCursor(-1);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    // Overridden by the hour/minute-specific subclasses to continue the flow.
    protected function onValueChosen(value as Number) as Void {
    }

    private function activate(row as Number, col as Number) as Void {
        if (mView.isDone(row, col)) {
            var value = mView.getValue();
            WatchUi.popView(WatchUi.SLIDE_LEFT);
            onValueChosen(value);
        } else {
            mView.pressKey(row, col);
        }
    }

}

function pushGoalHourKeypad(percent as Number) as Void {
    var view = new Charging_screenGoalKeypadView("In how many hours?", 23);
    WatchUi.pushView(view, new Charging_screenGoalHourKeypadDelegate(view, percent), WatchUi.SLIDE_LEFT);
}

class Charging_screenGoalHourKeypadDelegate extends Charging_screenGoalKeypadDelegate {

    private var mPercent as Number;

    function initialize(view as Charging_screenGoalKeypadView, percent as Number) {
        Charging_screenGoalKeypadDelegate.initialize(view);
        mPercent = percent;
    }

    protected function onValueChosen(hours as Number) as Void {
        pushGoalMinuteKeypad(mPercent, hours);
    }

}

function pushGoalMinuteKeypad(percent as Number, hours as Number) as Void {
    var view = new Charging_screenGoalKeypadView("+ how many minutes?", 59);
    WatchUi.pushView(view, new Charging_screenGoalMinuteKeypadDelegate(view, percent, hours), WatchUi.SLIDE_LEFT);
}

class Charging_screenGoalMinuteKeypadDelegate extends Charging_screenGoalKeypadDelegate {

    private var mPercent as Number;
    private var mHours as Number;

    function initialize(view as Charging_screenGoalKeypadView, percent as Number, hours as Number) {
        Charging_screenGoalKeypadDelegate.initialize(view);
        mPercent = percent;
        mHours = hours;
    }

    protected function onValueChosen(minutes as Number) as Void {
        ChargeGoal.set(mPercent, mHours, minutes);
        WatchUi.requestUpdate();
    }

}
