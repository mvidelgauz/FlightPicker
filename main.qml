import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: root
    width: 1400
    height: 900
    minimumWidth: 1100
    minimumHeight: 700
    visible: true
    title: (project.dirty ? "● " : "") + project.currentFileName + " — Flight Segment Picker"
    color: theme.windowBg

    // Geometry is saved on close / auto-save, loaded on start.

    // ── Theme ───────────────────────────────────────────────────
    property bool darkMode: appSettings.darkMode
    onDarkModeChanged: { appSettings.darkMode = darkMode; appSettings.save(); }

    QtObject {
        id: theme
        property color windowBg:       darkMode ? "#0a0e1a" : "#f0f0f0"
        property color headerBg:       darkMode ? "#0d1220" : "#ffffff"
        property color panelBg:        darkMode ? "#111827" : "#f5f5f5"
        property color cardBg:         darkMode ? "#1a2236" : "#ffffff"
        property color cardSelectedBg: darkMode ? "#1e2d4a" : "#cce4f7"
        property color textPrimary:    darkMode ? "#e8ecf4" : "#1a1a1a"
        property color textSecondary:  darkMode ? "#8896ab" : "#5f6368"
        property color accent:         darkMode ? "#d4a855" : "#0078d4"
        property color divider:        darkMode ? "#2a3550" : "#c8c8c8"
        property color inputBg:        darkMode ? "#151d30" : "#ffffff"
        property color inputBorder:    darkMode ? "#2a3550" : "#999999"
        property color inputFocusBorder: darkMode ? "#d4a855" : "#0078d4"
        property color buttonBg:       darkMode ? "#d4a855" : "#0078d4"
        property color buttonText:     darkMode ? "#0a0e1a" : "#ffffff"
        property color buttonHoverBg:  darkMode ? "#e0bb6e" : "#106ebe"
        property color dangerBg:       darkMode ? "#7f1d1d" : "#dc2626"
        property color dangerHover:    darkMode ? "#991b1b" : "#b91c1c"
        property color formBg:         darkMode ? "#0d1220" : "#e6e6e6"
        property color cardBorderCol:  darkMode ? "transparent" : "#c0c0c0"
        property color calendarBg:     darkMode ? "#1a2236" : "#ffffff"
        property color calendarDayHover: darkMode ? "#2a3550" : "#e0e0e0"
        property color calendarToday:  darkMode ? "#2a3550" : "#e8f0fe"
        property string fontFamily:    "Segoe UI"
        property int borderRadius:     darkMode ? 8 : 2
        property real cardBorderW:     darkMode ? 0 : 1
    }

    property int cellHeight: appSettings.cellHeight
    // highlightRow is recalculated only after resize settles (debounced)
    property int highlightRow: 2  // sensible default

    Timer {
        id: highlightRecalcTimer
        interval: 100; repeat: false
        onTriggered: {
            var newRow = Math.floor(flickArea.height / root.cellHeight / 2);
            if (newRow < 1) newRow = 1;
            root.highlightRow = newRow;
        }
    }

    // Trigger recalc when flickArea resizes, but debounced
    Connections {
        target: flickArea
        function onHeightChanged() { highlightRecalcTimer.restart(); }
    }

    // ── Data Models ─────────────────────────────────────────────
    ListModel { id: seg1Model }
    ListModel { id: seg2Model }
    ListModel { id: seg3Model }
    ListModel { id: seg4Model }

    // ── Dynamic airline/aircraft lists ──────────────────────────
    property var defaultAirlines: [
        "Air Arabia", "ANA", "El Al", "Emirates", "Etihad Airways",
        "flydubai", "Israir", "JAL", "Wizz Air Abu Dhabi"
    ]
    property var defaultAircraft: [
        "A320neo", "A321LR", "A321neo", "A330-300", "A330-900neo",
        "A350-900", "A350-1000", "A380",
        "B737 MAX 8", "B737 MAX 9", "B737-800",
        "B777-200LR", "B777-300ER", "B777-9",
        "B787-9", "B787-10"
    ]
    property var airlineList: []
    property var aircraftList: []
    // Version counters - incrementing these forces ComboBox model rebinding
    property int airlineListVersion: 0
    property int aircraftListVersion: 0

    function ensureInList(list, value) {
        if (!value || value.trim() === "") return list;
        var v = value.trim();
        for (var i = 0; i < list.length; i++) {
            if (list[i] === v) return list;
        }
        var copy = list.slice();
        copy.push(v);
        // Keep the list sorted (case-insensitive)
        copy.sort(function(a, b) {
            return a.toLowerCase().localeCompare(b.toLowerCase());
        });
        return copy;
    }

    // ── Airport timezone data (DST-aware) ─────────────────────────
    // Returns UTC offset in hours for a given airport on a given date.
    // Israel: UTC+2 standard (IST), UTC+3 daylight (IDT).
    //   DST runs last Friday before April 2 → last Sunday of October.
    //   Simplified: ~late March to ~late October.
    // UAE: UTC+4 all year (no DST).
    // Japan: UTC+9 all year (no DST).
    function getUtcOffset(airport, dateStr) {
        var code = (airport || "").toUpperCase();

        // UAE airports — always UTC+4
        if (code === "AUH" || code === "DXB" || code === "DWC" || code === "SHJ")
            return 4;

        // Japan airports — always UTC+9
        if (code === "NRT" || code === "HND" || code === "KIX" || code === "NGO" ||
            code === "CTS" || code === "FUK" || code === "ITM")
            return 9;

        // Israel (TLV) — DST-aware
        if (code === "TLV") {
            if (!dateStr) return 2;
            var parts = dateStr.split("-");
            if (parts.length < 3) return 2;
            var year = parseInt(parts[0]);
            var month = parseInt(parts[1]);
            var day = parseInt(parts[2]);

            // Israel DST: starts last Friday before April 2,
            //             ends last Sunday of October.
            // Approximate: DST if month is April–September (always),
            //   March: check if day >= last Friday before April 2
            //   October: check if day < last Sunday
            if (month >= 4 && month <= 9) return 3;  // summer
            if (month >= 11 || month <= 2) return 2;  // winter

            if (month === 3) {
                // Find last Friday before April 2 (i.e., last Friday in March
                // or March 26-31 area). Simplified: DST starts ~March 27.
                // More precisely, find the last Friday <= April 1.
                var apr1 = new Date(year, 3, 1); // April 1
                var apr1Dow = apr1.getDay(); // 0=Sun
                // Days back to previous Friday from April 1
                var daysBack = (apr1Dow + 2) % 7; // Fri=5, so (dow-5+7)%7 but simpler:
                // Sun=0→2, Mon=1→3, Tue=2→4, Wed=3→5, Thu=4→6, Fri=5→0, Sat=6→1
                if (apr1Dow === 5) daysBack = 0;
                else if (apr1Dow === 6) daysBack = 1;
                else daysBack = apr1Dow + 2;
                var dstStart = 1 - daysBack; // April day (could be negative = March)
                var dstStartDate = new Date(year, 3, dstStart); // handles negative
                var dstStartMonth = dstStartDate.getMonth() + 1;
                var dstStartDay = dstStartDate.getDate();
                if (month === 3 && day >= dstStartDay && dstStartMonth === 3) return 3;
                if (month === 3 && dstStartMonth < 3) return 3; // DST started in March
                return 2;
            }

            if (month === 10) {
                // Last Sunday of October
                var oct31 = new Date(year, 9, 31);
                var oct31Dow = oct31.getDay();
                var lastSun = 31 - oct31Dow;
                if (day < lastSun) return 3;  // still summer
                return 2;  // winter
            }

            return 2; // fallback
        }

        return 0; // unknown
    }

    function calcDuration(depDate, depTime, arrDate, arrTime, depAirport, arrAirport) {
        if (!depDate || !depTime || !arrDate || !arrTime) return "";
        var dp = depDate.split("-"); var ap = arrDate.split("-");
        var dt = depTime.split(":"); var at_ = arrTime.split(":");
        if (dp.length < 3 || ap.length < 3 || dt.length < 2 || at_.length < 2) return "";
        var depMs = new Date(parseInt(dp[0]), parseInt(dp[1])-1, parseInt(dp[2]),
                             parseInt(dt[0]), parseInt(dt[1])).getTime();
        var arrMs = new Date(parseInt(ap[0]), parseInt(ap[1])-1, parseInt(ap[2]),
                             parseInt(at_[0]), parseInt(at_[1])).getTime();
        if (isNaN(depMs) || isNaN(arrMs)) return "";

        // DST-aware UTC offsets
        var depOff = getUtcOffset(depAirport, depDate);
        var arrOff = getUtcOffset(arrAirport, arrDate);
        var diffMin = (arrMs - depMs) / 60000 - (arrOff - depOff) * 60;
        if (diffMin <= 0) return "";
        var h = Math.floor(diffMin / 60);
        var m = Math.round(diffMin % 60);
        return h + "h " + (m < 10 ? "0" : "") + m + "m";
    }

    // Calculate layover/stay duration between arrival of left flight and departure of right flight.
    // Returns "" if either flight is null, or "Xd Yh Zm" format.
    function calcLayover(leftFlight, rightFlight) {
        if (!leftFlight || !rightFlight) return "";
        var aDate = leftFlight.arrDate;
        var aTime = leftFlight.arrTime;
        var dDate = rightFlight.depDate;
        var dTime = rightFlight.depTime;
        if (!aDate || !aTime || !dDate || !dTime) return "";

        var ap = aDate.split("-"); var dp = dDate.split("-");
        var at_ = aTime.split(":"); var dt = dTime.split(":");
        if (ap.length < 3 || dp.length < 3 || at_.length < 2 || dt.length < 2) return "";

        var arrMs = new Date(parseInt(ap[0]), parseInt(ap[1])-1, parseInt(ap[2]),
                             parseInt(at_[0]), parseInt(at_[1])).getTime();
        var depMs = new Date(parseInt(dp[0]), parseInt(dp[1])-1, parseInt(dp[2]),
                             parseInt(dt[0]), parseInt(dt[1])).getTime();
        if (isNaN(arrMs) || isNaN(depMs)) return "";

        // Both times are local to the same city (same timezone)
        var diffMin = (depMs - arrMs) / 60000;
        var negative = diffMin < 0;
        var absDiff = Math.abs(diffMin);
        if (absDiff === 0) return "0m";

        var days = Math.floor(absDiff / (60 * 24));
        var hours = Math.floor((absDiff % (60 * 24)) / 60);
        var mins = Math.round(absDiff % 60);

        var parts = [];
        if (days > 0) parts.push(days + "d");
        if (hours > 0) parts.push(hours + "h");
        if (mins > 0) parts.push(mins + "m");
        var result = parts.join("\n");
        return negative ? "−" + result : result;
    }

    // Check if a layover string represents a negative (impossible) connection
    function isNegativeLayover(s) {
        return s.length > 0 && s.charAt(0) === '−';
    }

    // ── Airport city grouping ────────────────────────────────────
    // Airports in the same city are treated as connected for layover calculation.
    // Both times are in the same timezone so no adjustment is needed.
    function airportCity(code) {
        code = (code || "").toUpperCase();
        // UAE — all airports grouped (AUH, DXB, DWC, SHJ)
        if (code === "DXB" || code === "DWC" || code === "SHJ" || code === "AUH") return "UAE";
        // Tokyo
        if (code === "NRT" || code === "HND") return "TYO";
        // Osaka
        if (code === "KIX" || code === "ITM") return "OSA";
        // Nagoya
        if (code === "NGO") return "NGO";
        // Other Japan
        if (code === "CTS" || code === "FUK") return code;
        // Israel
        if (code === "TLV") return "TLV";
        return code; // fallback: code itself
    }

    function sameCity(a, b) {
        return airportCity(a) === airportCity(b);
    }

    // ── Smart layover calculation ─────────────────────────────────
    // Builds a chain of selected flights, skipping empty columns.
    // Layovers are shown between consecutive flights in the chain
    // where the arrival airport is in the same city as departure airport.
    // Each layover "belongs" to the gap between two column indices.

    // Returns an object: { "1-2": "1d\n10h", "1-4": "21d\n2h", ... }
    // Keys are "leftCol-rightCol" (0-based column indices).
    property var layovers: {
        var cols = [col1, col2, col3, col4];
        var chain = []; // { colIdx, flight }
        for (var i = 0; i < 4; i++) {
            var f = cols[i].selectedFlight;
            if (f && f.depDate && f.depTime && f.arrDate && f.arrTime) {
                chain.push({ colIdx: i, flight: f });
            }
        }

        var result = {};
        for (var j = 0; j < chain.length - 1; j++) {
            var left = chain[j];
            var right = chain[j + 1];
            // Show layover if arrival and departure are in the same city
            if (left.flight.arr && right.flight.dep &&
                sameCity(left.flight.arr, right.flight.dep)) {
                var text = calcLayover(left.flight, right.flight);
                if (text !== "") {
                    result[left.colIdx + "-" + right.colIdx] = text;
                }
            }
        }
        return result;
    }

    // Helper to get layover text for a specific gap (between column a and column b)
    function layoverBetween(a, b) {
        // Check for direct gap first
        var key = a + "-" + b;
        if (layovers[key]) return layovers[key];
        // Check for any layover that spans across this gap
        // (e.g., col 0→3 would be shown between cols 0 and 3)
        for (var k in layovers) {
            var parts = k.split("-");
            var left = parseInt(parts[0]);
            var right = parseInt(parts[1]);
            // This layover spans from left to right.
            // Show it in the gap that's closest to the midpoint,
            // or in the first gap after the left column.
            if (left < b && right > a && left <= a && right >= b) {
                return layovers[k];
            }
        }
        return "";
    }

    // The 3 gap positions between columns (0-1, 1-2, 2-3)
    property string layover12: {
        // Check for layovers that should display in gap 0↔1
        var l = layovers;
        if (l["0-1"]) return l["0-1"];
        return "";
    }
    property string layover23: {
        var l = layovers;
        if (l["1-2"]) return l["1-2"];
        // A skip from col 0 to col 2: show in gap 1↔2 (midpoint)
        if (l["0-2"]) return l["0-2"];
        return "";
    }
    property string layover34: {
        var l = layovers;
        if (l["2-3"]) return l["2-3"];
        // Skips: col 1→3 or col 0→3
        if (l["1-3"]) return l["1-3"];
        if (l["0-3"]) return l["0-3"];
        return "";
    }

    function airlineColor(name) {
        if (!darkMode) return theme.accent;
        var n = (name || "").toLowerCase();
        if (n.indexOf("etihad") >= 0)    return "#c9a84c";
        if (n.indexOf("emirates") >= 0)  return "#d4232a";
        if (n.indexOf("flydubai") >= 0)  return "#f58220";
        if (n.indexOf("jal") >= 0)       return "#e60012";
        if (n.indexOf("ana") >= 0)       return "#00467f";
        return theme.accent;
    }

    function parsePrice(p) {
        if (!p) return 0;
        return parseFloat(p.replace(/[^0-9.]/g, "")) || 0;
    }

    // ── Combo pricing ───────────────────────────────────────────
    // Looks up the current 4-leg selection in project.combos.
    // Each combo: { "legs": ["EK 2370", "EK 320", "EK 321", "EK 2369"], "price": "$1,254" }
    // Returns the combo price string if found, or "" if no match.
    property string comboPrice: {
        var combos = project.combos;
        if (!combos || combos.length === 0) return "";
        var cols = [col1, col2, col3, col4];
        var selected = [];
        for (var i = 0; i < 4; i++) {
            var f = cols[i].selectedFlight;
            selected.push(f ? (f.flightNo || "").trim() : "");
        }
        for (var c = 0; c < combos.length; c++) {
            var combo = combos[c];
            var legs = combo.legs;
            if (!legs || legs.length !== 4) continue;
            var match = true;
            for (var k = 0; k < 4; k++) {
                var comboLeg = ("" + (legs[k] || "")).trim();
                // Empty combo leg means "any flight" in that slot
                if (comboLeg === "") continue;
                if (comboLeg !== selected[k]) { match = false; break; }
            }
            if (match) return "" + (combo.price || "");
        }
        return "";
    }

    // Sum of individual per-card prices (the old approach, as fallback)
    property real perLegPriceSum: {
        var t = 0;
        if (col1.selectedFlight) t += parsePrice(col1.selectedFlight.price);
        if (col2.selectedFlight) t += parsePrice(col2.selectedFlight.price);
        if (col3.selectedFlight) t += parsePrice(col3.selectedFlight.price);
        if (col4.selectedFlight) t += parsePrice(col4.selectedFlight.price);
        return t;
    }

    // Display price: combo price if found, else per-leg sum, else 0
    property string displayPrice: {
        if (comboPrice !== "") return comboPrice;
        if (perLegPriceSum > 0) return "$" + perLegPriceSum.toFixed(0);
        return "";
    }

    // ── Persistence ─────────────────────────────────────────────
    // ListModel.get(i) returns a ListElement, not a plain JS object.
    // We must manually copy each property into a plain object for
    // QVariantList serialization to work correctly.
    property var flightFields: [
        "airline", "flightNo", "aircraft", "dep", "arr",
        "depDate", "depTime", "arrDate", "arrTime",
        "duration", "price"
    ]

    function modelToArray(mdl) {
        var arr = [];
        for (var i = 0; i < mdl.count; i++) {
            var item = mdl.get(i);
            var obj = {};
            for (var f = 0; f < flightFields.length; f++) {
                var key = flightFields[f];
                obj[key] = item[key] || "";
            }
            arr.push(obj);
        }
        return arr;
    }
    function arrayToModel(arr, mdl) {
        mdl.clear();
        for (var i = 0; i < arr.length; i++) mdl.append(arr[i]);
    }

    // Save UI settings (geometry, theme) to AppData
    function saveSettings() {
        appSettings.windowX = root.x;
        appSettings.windowY = root.y;
        appSettings.windowW = root.width;
        appSettings.windowH = root.height;
        appSettings.darkMode = root.darkMode;
        appSettings.save();
    }

    // Push current QML state into the project C++ object
    function pushToProject() {
        project.airlines = root.airlineList;
        project.aircraft = root.aircraftList;
        project.seg1 = modelToArray(seg1Model);
        project.seg2 = modelToArray(seg2Model);
        project.seg3 = modelToArray(seg3Model);
        project.seg4 = modelToArray(seg4Model);
        // combos are kept on project directly — no QML model needed
    }

    // Save project to its current file (or trigger Save As if no file yet)
    function saveProject() {
        pushToProject();
        if (project.hasFile()) {
            project.save();
        } else {
            // C++ shows native Save As dialog; returns true if user picked a file
            pushToProject();
            project.saveFileDialog();
        }
    }

    // Save all (settings + project auto-save)
    function saveAll() {
        saveSettings();
        pushToProject();
        if (project.hasFile()) project.save();
    }

    // Load project data from the C++ object into QML models
    function pullFromProject() {
        var savedAl = project.airlines;
        var merged = defaultAirlines.slice();
        if (savedAl && savedAl.length > 0) {
            for (var i = 0; i < savedAl.length; i++) {
                var s = "" + savedAl[i];
                if (s !== "" && s !== "undefined") merged = ensureInList(merged, s);
            }
        }
        root.airlineList = merged;
        root.airlineListVersion++;

        var savedAc = project.aircraft;
        var mergedAc = defaultAircraft.slice();
        if (savedAc && savedAc.length > 0) {
            for (var j = 0; j < savedAc.length; j++) {
                var t = "" + savedAc[j];
                if (t !== "" && t !== "undefined") mergedAc = ensureInList(mergedAc, t);
            }
        }
        root.aircraftList = mergedAc;
        root.aircraftListVersion++;

        seg1Model.clear(); seg2Model.clear(); seg3Model.clear(); seg4Model.clear();
        if (project.seg1.length > 0) arrayToModel(project.seg1, seg1Model);
        if (project.seg2.length > 0) arrayToModel(project.seg2, seg2Model);
        if (project.seg3.length > 0) arrayToModel(project.seg3, seg3Model);
        if (project.seg4.length > 0) arrayToModel(project.seg4, seg4Model);
    }

    function loadAll() {
        // Restore window geometry
        root.x = appSettings.windowX;
        root.y = appSettings.windowY;
        root.width = appSettings.windowW;
        root.height = appSettings.windowH;
        root.darkMode = appSettings.darkMode;

        // Pull project data (already loaded by C++ from --project or last file)
        pullFromProject();
    }

    // ── File operations (New / Open / Save / Save As) ───────────
    function doNewProject() {
        project.newProject();
        seg1Model.clear(); seg2Model.clear(); seg3Model.clear(); seg4Model.clear();
        root.airlineList = defaultAirlines.slice();
        root.airlineListVersion++;
        root.aircraftList = defaultAircraft.slice();
        root.aircraftListVersion++;
    }

    function doOpenProject() {
        if (project.openFileDialog()) {
            pullFromProject();
        }
    }

    function doSaveAs() {
        pushToProject();
        project.saveFileDialog();
    }

    // File dialogs are handled in C++ (ProjectData::openFileDialog / saveFileDialog)

    Component.onCompleted: {
        loadAll();
        // Delay initial highlightRow calc to after first layout pass
        Qt.callLater(function() {
            var newRow = Math.floor(flickArea.height / root.cellHeight / 2);
            if (newRow < 1) newRow = 1;
            root.highlightRow = newRow;
        });
    }
    onClosing: saveAll()

    // Auto-save timer (every 30 seconds)
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: saveAll()
    }

    // ── Edit Dialog (overlay) ───────────────────────────────────
    property int editSegment: -1
    property int editIndex: -1
    property var editData: null

    function openEditDialog(seg, idx) {
        var mdl = [seg1Model, seg2Model, seg3Model, seg4Model][seg];
        editSegment = seg;
        editIndex = idx;
        editData = {
            airline: mdl.get(idx).airline || "",
            flightNo: mdl.get(idx).flightNo || "",
            aircraft: mdl.get(idx).aircraft || "",
            dep: mdl.get(idx).dep || "",
            arr: mdl.get(idx).arr || "",
            depDate: mdl.get(idx).depDate || "",
            depTime: mdl.get(idx).depTime || "",
            arrDate: mdl.get(idx).arrDate || "",
            arrTime: mdl.get(idx).arrTime || "",
            price: mdl.get(idx).price || "",
            duration: mdl.get(idx).duration || ""
        };
        editDialog.open();
    }

    function applyEdit() {
        if (editSegment < 0 || editIndex < 0) return;
        var mdl = [seg1Model, seg2Model, seg3Model, seg4Model][editSegment];
        var d = editData;
        // Recalc duration
        d.duration = calcDuration(d.depDate, d.depTime, d.arrDate, d.arrTime, d.dep, d.arr);
        mdl.set(editIndex, d);
        // Add new airline/aircraft to lists if needed
        root.airlineList = ensureInList(root.airlineList, d.airline);
        root.airlineListVersion++;
        root.aircraftList = ensureInList(root.aircraftList, d.aircraft);
        root.aircraftListVersion++;
        saveAll();
    }

    function removeCard(seg, idx) {
        var mdl = [seg1Model, seg2Model, seg3Model, seg4Model][seg];
        mdl.remove(idx);
        saveAll();
    }

    // ── Edit Dialog Popup ───────────────────────────────────────
    Popup {
        id: editDialog
        anchors.centerIn: parent
        width: 440; height: 420
        modal: true; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: theme.cardBg
            border.color: theme.accent; border.width: 2
            radius: theme.borderRadius + 4
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Text {
                text: "Edit Flight"
                font.pixelSize: 16; font.weight: Font.Bold
                font.family: theme.fontFamily; color: theme.accent
            }

            GridLayout {
                columns: 4; Layout.fillWidth: true
                columnSpacing: 8; rowSpacing: 6

                Text { text: "Airline"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                EditableCombo {
                    id: edAirline; Layout.columnSpan: 3; Layout.fillWidth: true
                    model: { root.airlineListVersion; return root.airlineList; }
                    editText: editData ? editData.airline : ""
                    onEditTextChanged: if (editData) editData.airline = editText
                }

                Text { text: "Flight #"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                FormField {
                    id: edFlightNo; Layout.columnSpan: 3; Layout.fillWidth: true
                    text: editData ? editData.flightNo : ""
                    onTextChanged: if (editData) editData.flightNo = text
                }

                Text { text: "Aircraft"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                EditableCombo {
                    id: edAircraft; Layout.columnSpan: 3; Layout.fillWidth: true
                    model: { root.aircraftListVersion; return root.aircraftList; }
                    editText: editData ? editData.aircraft : ""
                    onEditTextChanged: if (editData) editData.aircraft = editText
                }

                Text { text: "From"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                FormField {
                    id: edDep; Layout.fillWidth: true
                    text: editData ? editData.dep : ""
                    onTextChanged: if (editData) editData.dep = text
                }
                Text { text: "To"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                FormField {
                    id: edArr; Layout.fillWidth: true
                    text: editData ? editData.arr : ""
                    onTextChanged: if (editData) editData.arr = text
                }

                Text { text: "Dep Date"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                DatePickerField {
                    id: edDepDate; Layout.fillWidth: true
                    selectedDate: editData ? editData.depDate : ""
                    onSelectedDateChanged: if (editData) editData.depDate = selectedDate
                }
                Text { text: "Dep Time"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                FormField {
                    id: edDepTime; Layout.fillWidth: true
                    text: editData ? editData.depTime : ""
                    placeholderText: "HH:MM"
                    onTextChanged: if (editData) editData.depTime = text
                }

                Text { text: "Arr Date"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                DatePickerField {
                    id: edArrDate; Layout.fillWidth: true
                    selectedDate: editData ? editData.arrDate : ""
                    minDate: edDepDate.selectedDate
                    onSelectedDateChanged: if (editData) editData.arrDate = selectedDate
                }
                Text { text: "Arr Time"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                FormField {
                    id: edArrTime; Layout.fillWidth: true
                    text: editData ? editData.arrTime : ""
                    placeholderText: "HH:MM"
                    onTextChanged: if (editData) editData.arrTime = text
                }

                Text { text: "Price"; font.pixelSize: 11; font.family: theme.fontFamily; color: theme.textSecondary }
                FormField {
                    id: edPrice; Layout.columnSpan: 3; Layout.fillWidth: true
                    text: editData ? editData.price : ""
                    placeholderText: "$"
                    onTextChanged: if (editData) editData.price = text
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true; spacing: 8

                // Delete button
                Rectangle {
                    Layout.preferredWidth: 80; Layout.preferredHeight: 32
                    radius: theme.borderRadius
                    color: delMA.containsMouse ? theme.dangerHover : theme.dangerBg
                    Text {
                        anchors.centerIn: parent; text: "Delete"
                        font.pixelSize: 12; font.weight: Font.Bold
                        font.family: theme.fontFamily; color: "#ffffff"
                    }
                    MouseArea {
                        id: delMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            removeCard(editSegment, editIndex);
                            editDialog.close();
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 80; Layout.preferredHeight: 32
                    radius: theme.borderRadius
                    color: theme.divider
                    Text {
                        anchors.centerIn: parent; text: "Cancel"
                        font.pixelSize: 12; font.family: theme.fontFamily; color: theme.textPrimary
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: editDialog.close()
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 80; Layout.preferredHeight: 32
                    radius: theme.borderRadius
                    color: saveMA.containsMouse ? theme.buttonHoverBg : theme.buttonBg
                    Text {
                        anchors.centerIn: parent; text: "Save"
                        font.pixelSize: 12; font.weight: Font.Bold
                        font.family: theme.fontFamily; color: theme.buttonText
                    }
                    MouseArea {
                        id: saveMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { applyEdit(); editDialog.close(); }
                    }
                }
            }
        }
    }

    // ── Keyboard shortcuts ──────────────────────────────────────
    Shortcut { sequence: "Ctrl+N"; onActivated: doNewProject() }
    Shortcut { sequence: "Ctrl+O"; onActivated: doOpenProject() }
    Shortcut { sequence: "Ctrl+S"; onActivated: saveProject() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: doSaveAs() }

    // ── Main Layout ─────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ── Header ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            Layout.minimumHeight: 50
            Layout.maximumHeight: 50
            color: theme.headerBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 6

                Text {
                    text: "✈"; font.pixelSize: 18; color: theme.accent
                    Layout.preferredWidth: implicitWidth
                }
                Text {
                    text: "FLIGHT SEGMENT PICKER"
                    font.pixelSize: 12; font.weight: Font.Bold
                    font.letterSpacing: 2; font.family: theme.fontFamily
                    color: theme.textPrimary
                    Layout.preferredWidth: implicitWidth
                }

                Item { Layout.preferredWidth: 8 }

                // File operation buttons
                Repeater {
                    model: [
                        { label: "New",     icon: "📄", action: function() { doNewProject(); } },
                        { label: "Open",    icon: "📂", action: function() { doOpenProject(); } },
                        { label: "Save",    icon: "💾", action: function() { saveProject(); } },
                        { label: "Save As", icon: "📋", action: function() { doSaveAs(); } }
                    ]

                    Rectangle {
                        Layout.preferredWidth: fileBtnRow.implicitWidth + 12
                        Layout.preferredHeight: 28
                        radius: theme.borderRadius
                        color: fileBtnMA.containsMouse
                               ? (darkMode ? "#1e2d4a" : "#d0d0d0")
                               : "transparent"

                        Row {
                            id: fileBtnRow
                            anchors.centerIn: parent; spacing: 3
                            Text {
                                text: modelData.icon; font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.label
                                font.pixelSize: 11; font.family: theme.fontFamily
                                color: theme.textPrimary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: fileBtnMA; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.action()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Project filename indicator
                Text {
                    text: project.currentFileName
                    font.pixelSize: 10; font.italic: true
                    font.family: theme.fontFamily; color: theme.textSecondary
                    Layout.preferredWidth: implicitWidth
                    visible: project.hasFile()
                }

                Item { Layout.preferredWidth: 8 }

                // Total price badge
                Rectangle {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 30
                    radius: theme.borderRadius
                    color: theme.accent
                    opacity: root.displayPrice !== "" ? 1.0 : 0.35

                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text {
                            text: root.comboPrice !== "" ? "R/T:" : "TOTAL:"
                            font.pixelSize: 10; font.weight: Font.Bold
                            font.letterSpacing: 1; font.family: theme.fontFamily
                            color: theme.buttonText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.displayPrice !== "" ? root.displayPrice : "$0"
                            font.pixelSize: 13; font.weight: Font.Bold
                            font.family: theme.fontFamily; color: theme.buttonText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Theme toggle button - fixed width
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 30
                    radius: theme.borderRadius
                    color: darkMode ? "#1a2236" : "#d9d9d9"
                    border.color: theme.divider; border.width: 1

                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text {
                            text: darkMode ? "☀" : "🌙"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: darkMode ? "Light" : "Dark"
                            font.pixelSize: 11; font.family: theme.fontFamily
                            color: theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.darkMode = !root.darkMode
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1; color: theme.divider
            }
        }

        // ── Column Headers ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40
            Layout.minimumHeight: 40; Layout.maximumHeight: 40
            color: theme.panelBg
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                Repeater {
                    model: [
                        { label: "① TLV → UAE",  sub: "Outbound Leg 1" },
                        { label: "② UAE → Japan", sub: "Outbound Leg 2" },
                        { label: "③ Japan → UAE", sub: "Return Leg 1" },
                        { label: "④ UAE → TLV",   sub: "Return Leg 2" }
                    ]
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; color: "transparent"
                        Column {
                            anchors.centerIn: parent; spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label
                                font.pixelSize: 12; font.weight: Font.DemiBold
                                font.family: theme.fontFamily; color: theme.accent
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter; text: modelData.sub
                                font.pixelSize: 9; font.family: theme.fontFamily; color: theme.textSecondary
                            }
                        }
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: theme.divider }
        }

        // ── Main Scroll Area ────────────────────────────────────
        Item {
            id: flickArea; Layout.fillWidth: true; Layout.fillHeight: true

            // Highlight band
            Rectangle {
                x: 0; y: root.highlightRow * root.cellHeight
                width: parent.width; height: root.cellHeight; color: "transparent"; z: 0
                Rectangle { anchors.top: parent.top; width: parent.width; height: 2; color: theme.accent }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: theme.accent }
                Rectangle {
                    anchors.fill: parent; anchors.topMargin: 2; anchors.bottomMargin: 2
                    color: theme.accent; opacity: darkMode ? 0.06 : 0.08
                }
                Text { anchors.left: parent.left; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter; text: "▸"; font.pixelSize: 14; color: theme.accent; opacity: 0.6 }
                Text { anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; text: "◂"; font.pixelSize: 14; color: theme.accent; opacity: 0.6 }
            }

            // Fade gradients
            Rectangle {
                anchors.top: parent.top; width: parent.width
                height: root.cellHeight * 1.2; z: 10; enabled: false
                gradient: Gradient {
                    GradientStop { position: 0.0; color: theme.windowBg }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom; width: parent.width
                height: root.cellHeight * 1.2; z: 10; enabled: false
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: theme.windowBg }
                }
            }

            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 4; z: 1

                FlightColumn { id: col1; Layout.fillWidth: true; Layout.fillHeight: true; model: seg1Model; columnIndex: 0 }
                // Layover 1→2
                Item {
                    Layout.preferredWidth: 34; Layout.fillHeight: true
                    clip: true
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: root.highlightRow * root.cellHeight; width: 1; height: root.cellHeight; color: theme.divider; opacity: 0.5 }

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.highlightRow * root.cellHeight + (root.cellHeight - height) / 2
                        rotation: -90
                        transformOrigin: Item.Center
                        visible: root.layover12 !== ""
                        width: lay12Text.paintedWidth
                        height: lay12Text.paintedHeight

                        Text {
                            id: lay12Text
                            anchors.centerIn: parent
                            text: root.layover12.replace(/\n/g, " ")
                            font.pixelSize: 20; font.family: theme.fontFamily
                            font.weight: Font.DemiBold
                            color: isNegativeLayover(root.layover12) ? "#cc0000" : theme.accent; opacity: 0.85
                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 1.1
                        }
                    }
                }
                FlightColumn { id: col2; Layout.fillWidth: true; Layout.fillHeight: true; model: seg2Model; columnIndex: 1 }
                // Layover 2→3
                Item {
                    Layout.preferredWidth: 34; Layout.fillHeight: true
                    clip: true
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: root.highlightRow * root.cellHeight; width: 1; height: root.cellHeight; color: theme.divider; opacity: 0.5 }

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.highlightRow * root.cellHeight + (root.cellHeight - height) / 2
                        rotation: -90
                        transformOrigin: Item.Center
                        visible: root.layover23 !== ""
                        width: lay23Text.paintedWidth
                        height: lay23Text.paintedHeight

                        Text {
                            id: lay23Text
                            anchors.centerIn: parent
                            text: root.layover23.replace(/\n/g, " ")
                            font.pixelSize: 20; font.family: theme.fontFamily
                            font.weight: Font.DemiBold
                            color: isNegativeLayover(root.layover23) ? "#cc0000" : theme.accent; opacity: 0.85
                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 1.1
                        }
                    }
                }
                FlightColumn { id: col3; Layout.fillWidth: true; Layout.fillHeight: true; model: seg3Model; columnIndex: 2 }
                // Layover 3→4
                Item {
                    Layout.preferredWidth: 34; Layout.fillHeight: true
                    clip: true
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: root.highlightRow * root.cellHeight; width: 1; height: root.cellHeight; color: theme.divider; opacity: 0.5 }

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.highlightRow * root.cellHeight + (root.cellHeight - height) / 2
                        rotation: -90
                        transformOrigin: Item.Center
                        visible: root.layover34 !== ""
                        width: lay34Text.paintedWidth
                        height: lay34Text.paintedHeight

                        Text {
                            id: lay34Text
                            anchors.centerIn: parent
                            text: root.layover34.replace(/\n/g, " ")
                            font.pixelSize: 20; font.family: theme.fontFamily
                            font.weight: Font.DemiBold
                            color: isNegativeLayover(root.layover34) ? "#cc0000" : theme.accent; opacity: 0.85
                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 1.1
                        }
                    }
                }
                FlightColumn { id: col4; Layout.fillWidth: true; Layout.fillHeight: true; model: seg4Model; columnIndex: 3 }
            }

            Text {
                anchors.centerIn: parent
                visible: seg1Model.count === 0 && seg2Model.count === 0 && seg3Model.count === 0 && seg4Model.count === 0
                text: "No flights added yet.\nUse the form below to add flights."
                font.pixelSize: 15; font.family: theme.fontFamily
                color: theme.textSecondary; opacity: 0.5; horizontalAlignment: Text.AlignHCenter; z: 5
            }
        }

        // ── Selected Summary Bar ────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            Layout.minimumHeight: 52
            Layout.maximumHeight: 52
            color: theme.headerBg

            Rectangle {
                anchors.top: parent.top; width: parent.width; height: 1
                color: theme.divider
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 4

                Text {
                    text: "SELECTED:"
                    font.pixelSize: 10; font.weight: Font.Bold
                    font.letterSpacing: 2; font.family: theme.fontFamily
                    color: theme.textSecondary
                    Layout.preferredWidth: implicitWidth
                }

                // Seg 1
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 38
                    radius: theme.borderRadius; color: theme.cardBg
                    border.color: theme.divider; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        visible: col1.selectedFlight !== null
                        Text { text: col1.selectedFlight ? col1.selectedFlight.flightNo : ""; font.pixelSize: 9; font.weight: Font.DemiBold; font.family: theme.fontFamily; color: theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: { var f = col1.selectedFlight; if (!f) return ""; return f.depDate + " " + f.depTime + " → " + f.arrTime; } font.pixelSize: 8; font.family: theme.fontFamily; color: theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: col1.selectedFlight ? col1.selectedFlight.price : ""; font.pixelSize: 10; font.weight: Font.Bold; font.family: theme.fontFamily; color: theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { anchors.centerIn: parent; visible: col1.selectedFlight === null; text: "—"; font.pixelSize: 13; color: theme.textSecondary }
                }

                // Layover 1→2
                Text {
                    Layout.preferredWidth: 26
                    text: root.layover12
                    visible: root.layover12 !== ""
                    font.pixelSize: 7; font.family: theme.fontFamily; font.weight: Font.DemiBold
                    color: isNegativeLayover(root.layover12) ? "#cc0000" : theme.accent; horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.1
                }

                // Seg 2
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 38
                    radius: theme.borderRadius; color: theme.cardBg
                    border.color: theme.divider; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        visible: col2.selectedFlight !== null
                        Text { text: col2.selectedFlight ? col2.selectedFlight.flightNo : ""; font.pixelSize: 9; font.weight: Font.DemiBold; font.family: theme.fontFamily; color: theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: { var f = col2.selectedFlight; if (!f) return ""; return f.depDate + " " + f.depTime + " → " + f.arrTime; } font.pixelSize: 8; font.family: theme.fontFamily; color: theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: col2.selectedFlight ? col2.selectedFlight.price : ""; font.pixelSize: 10; font.weight: Font.Bold; font.family: theme.fontFamily; color: theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { anchors.centerIn: parent; visible: col2.selectedFlight === null; text: "—"; font.pixelSize: 13; color: theme.textSecondary }
                }

                // Layover 2→3
                Text {
                    Layout.preferredWidth: 26
                    text: root.layover23
                    visible: root.layover23 !== ""
                    font.pixelSize: 7; font.family: theme.fontFamily; font.weight: Font.DemiBold
                    color: isNegativeLayover(root.layover23) ? "#cc0000" : theme.accent; horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.1
                }

                // Seg 3
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 38
                    radius: theme.borderRadius; color: theme.cardBg
                    border.color: theme.divider; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        visible: col3.selectedFlight !== null
                        Text { text: col3.selectedFlight ? col3.selectedFlight.flightNo : ""; font.pixelSize: 9; font.weight: Font.DemiBold; font.family: theme.fontFamily; color: theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: { var f = col3.selectedFlight; if (!f) return ""; return f.depDate + " " + f.depTime + " → " + f.arrTime; } font.pixelSize: 8; font.family: theme.fontFamily; color: theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: col3.selectedFlight ? col3.selectedFlight.price : ""; font.pixelSize: 10; font.weight: Font.Bold; font.family: theme.fontFamily; color: theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { anchors.centerIn: parent; visible: col3.selectedFlight === null; text: "—"; font.pixelSize: 13; color: theme.textSecondary }
                }

                // Layover 3→4
                Text {
                    Layout.preferredWidth: 26
                    text: root.layover34
                    visible: root.layover34 !== ""
                    font.pixelSize: 7; font.family: theme.fontFamily; font.weight: Font.DemiBold
                    color: isNegativeLayover(root.layover34) ? "#cc0000" : theme.accent; horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.1
                }

                // Seg 4
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 38
                    radius: theme.borderRadius; color: theme.cardBg
                    border.color: theme.divider; border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        visible: col4.selectedFlight !== null
                        Text { text: col4.selectedFlight ? col4.selectedFlight.flightNo : ""; font.pixelSize: 9; font.weight: Font.DemiBold; font.family: theme.fontFamily; color: theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: { var f = col4.selectedFlight; if (!f) return ""; return f.depDate + " " + f.depTime + " → " + f.arrTime; } font.pixelSize: 8; font.family: theme.fontFamily; color: theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: col4.selectedFlight ? col4.selectedFlight.price : ""; font.pixelSize: 10; font.weight: Font.Bold; font.family: theme.fontFamily; color: theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { anchors.centerIn: parent; visible: col4.selectedFlight === null; text: "—"; font.pixelSize: 13; color: theme.textSecondary }
                }
            }
        }

        // ── Input Forms Row ─────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 250
            Layout.minimumHeight: 250; Layout.maximumHeight: 250
            color: theme.formBg
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: theme.divider }
            RowLayout {
                anchors.fill: parent; anchors.margins: 6; spacing: 8
                FlightInputForm {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    segmentDepAirports: ["TLV"]
                    segmentArrAirports: ["AUH", "DXB", "DWC", "SHJ"]
                    defaultDepIdx: 0; defaultArrIdx: 0
                    onAddFlight: function(d) { seg1Model.append(d); saveAll(); }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: theme.divider; opacity: 0.5 }
                FlightInputForm {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    segmentDepAirports: ["AUH", "DXB", "DWC", "SHJ"]
                    segmentArrAirports: ["NRT", "HND", "KIX", "NGO", "CTS", "FUK", "ITM"]
                    defaultDepIdx: 0; defaultArrIdx: 0
                    onAddFlight: function(d) { seg2Model.append(d); saveAll(); }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: theme.divider; opacity: 0.5 }
                FlightInputForm {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    segmentDepAirports: ["NRT", "HND", "KIX", "NGO", "CTS", "FUK", "ITM"]
                    segmentArrAirports: ["AUH", "DXB", "DWC", "SHJ"]
                    defaultDepIdx: 0; defaultArrIdx: 0
                    onAddFlight: function(d) { seg3Model.append(d); saveAll(); }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: theme.divider; opacity: 0.5 }
                FlightInputForm {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    segmentDepAirports: ["AUH", "DXB", "DWC", "SHJ"]
                    segmentArrAirports: ["TLV"]
                    defaultDepIdx: 0; defaultArrIdx: 0
                    onAddFlight: function(d) { seg4Model.append(d); saveAll(); }
                }
            }
        }
    }
}
