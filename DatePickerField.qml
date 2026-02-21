import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// A date field that shows a calendar popup to pick a date.
// selectedDate: "YYYY-MM-DD" string.
// The calendar opens UPWARD and is parented to the window overlay
// so it is never clipped by scroll areas or form containers.

Item {
    id: dpf
    height: 26
    property string selectedDate: ""
    property string placeholderText: "Select date"
    property string minDate: ""  // "YYYY-MM-DD" — days before this are disabled

    // Current calendar view month/year
    property int viewYear: {
        // If we have a selected date, view that month
        if (selectedDate) {
            var p = selectedDate.split("-");
            return parseInt(p[0]) || new Date().getFullYear();
        }
        // If we have a minDate, start viewing that month
        if (minDate) {
            var p2 = minDate.split("-");
            return parseInt(p2[0]) || new Date().getFullYear();
        }
        return new Date().getFullYear();
    }
    property int viewMonth: {
        if (selectedDate) {
            var p = selectedDate.split("-");
            return (parseInt(p[1]) || (new Date().getMonth() + 1));
        }
        if (minDate) {
            var p2 = minDate.split("-");
            return (parseInt(p2[1]) || (new Date().getMonth() + 1));
        }
        return new Date().getMonth() + 1;
    }

    // The clickable field
    Rectangle {
        id: fieldBg
        anchors.fill: parent
        radius: theme.borderRadius
        color: theme.inputBg
        border.color: theme.inputBorder
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6; anchors.rightMargin: 4
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: dpf.selectedDate || dpf.placeholderText
                font.pixelSize: 11; font.family: theme.fontFamily
                color: dpf.selectedDate ? theme.textPrimary : theme.textSecondary
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            Text {
                text: "📅"; font.pixelSize: 10
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (calPopup.visible) {
                    calPopup.close();
                } else {
                    positionAndOpen();
                }
            }
        }
    }

    // Position the popup in window-global coordinates, opening upward
    function positionAndOpen() {
        // Map the field's top-left to the window (overlay) coordinate space
        var globalPos = dpf.mapToGlobal(0, 0);
        var windowPos = root.contentItem.mapFromGlobal(globalPos.x, globalPos.y);

        calPopup.x = windowPos.x;
        // Open upward: place popup bottom edge at the field's top edge, with a small gap
        calPopup.y = windowPos.y - calPopup.height - 4;

        // If that would go above the window top, flip to below
        if (calPopup.y < 0) {
            calPopup.y = windowPos.y + dpf.height + 4;
        }

        calPopup.open();
    }

    // The calendar popup, parented to the window overlay so it's never clipped
    Popup {
        id: calPopup
        parent: Overlay.overlay
        width: 250; height: 280
        modal: false; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        background: Rectangle {
            color: theme.calendarBg
            radius: theme.borderRadius + 2
            border.color: theme.accent
            border.width: 1

            // Simple shadow via a slightly offset/enlarged rect behind
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                z: -1
                radius: parent.radius + 1
                color: "#40000000"
            }
        }

        contentItem: ColumnLayout {
            spacing: 0

            // ── Month/Year navigation ───────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    spacing: 4

                    // Prev month
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: pmMA.containsMouse ? theme.calendarDayHover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "◀"; font.pixelSize: 10; color: theme.textSecondary
                        }
                        MouseArea {
                            id: pmMA; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: prevMonth()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: monthName(dpf.viewMonth) + " " + dpf.viewYear
                        font.pixelSize: 13; font.weight: Font.DemiBold
                        font.family: theme.fontFamily; color: theme.textPrimary
                    }

                    Item { Layout.fillWidth: true }

                    // Next month
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: nmMA.containsMouse ? theme.calendarDayHover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "▶"; font.pixelSize: 10; color: theme.textSecondary
                        }
                        MouseArea {
                            id: nmMA; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: nextMonth()
                        }
                    }
                }
            }

            // ── Day-of-week headers ─────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                Layout.leftMargin: 6; Layout.rightMargin: 6
                spacing: 0

                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Text {
                        Layout.fillWidth: true
                        text: modelData
                        font.pixelSize: 9; font.weight: Font.Bold
                        font.family: theme.fontFamily
                        color: theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ── Day grid ────────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.leftMargin: 6; Layout.rightMargin: 6; Layout.bottomMargin: 6
                columns: 7; rowSpacing: 2; columnSpacing: 0

                Repeater {
                    id: dayRepeater
                    model: getDayCells()

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 14
                        color: {
                            if (modelData.day <= 0 || modelData.disabled) return "transparent";
                            if (modelData.selected) return theme.accent;
                            if (modelData.today) return theme.calendarToday;
                            if (dayItemMA.containsMouse) return theme.calendarDayHover;
                            return "transparent";
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day > 0 ? modelData.day : ""
                            font.pixelSize: 11; font.family: theme.fontFamily
                            font.weight: modelData.selected ? Font.Bold : Font.Normal
                            opacity: modelData.disabled ? 0.3 : 1.0
                            color: {
                                if (modelData.day <= 0) return "transparent";
                                if (modelData.disabled) return theme.textSecondary;
                                if (modelData.selected) return theme.buttonText;
                                return theme.textPrimary;
                            }
                        }

                        MouseArea {
                            id: dayItemMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (modelData.day > 0 && !modelData.disabled)
                                         ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData.day <= 0 || modelData.disabled) return;
                                var mm = dpf.viewMonth < 10 ? "0" + dpf.viewMonth : "" + dpf.viewMonth;
                                var dd = modelData.day < 10 ? "0" + modelData.day : "" + modelData.day;
                                dpf.selectedDate = dpf.viewYear + "-" + mm + "-" + dd;
                                calPopup.close();
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Helper functions ────────────────────────────────────────
    function monthName(m) {
        var names = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return names[m] || "";
    }

    function prevMonth() {
        var m = viewMonth - 1;
        var y = viewYear;
        if (m < 1) { m = 12; y--; }
        viewMonth = m; viewYear = y;
    }

    function nextMonth() {
        var m = viewMonth + 1;
        var y = viewYear;
        if (m > 12) { m = 1; y++; }
        viewMonth = m; viewYear = y;
    }

    function getDayCells() {
        var cells = [];
        var firstDay = new Date(viewYear, viewMonth - 1, 1);
        var dow = firstDay.getDay(); // 0=Sun
        var startOffset = (dow === 0) ? 6 : dow - 1; // Monday=0

        var daysInMonth = new Date(viewYear, viewMonth, 0).getDate();

        var today = new Date();
        var todayStr = today.getFullYear() + "-" +
                       (today.getMonth() + 1 < 10 ? "0" : "") + (today.getMonth() + 1) + "-" +
                       (today.getDate() < 10 ? "0" : "") + today.getDate();

        // Parse minDate for comparison
        var minDateVal = "";
        if (dpf.minDate && dpf.minDate.length === 10) {
            minDateVal = dpf.minDate; // "YYYY-MM-DD" string comparison works
        }

        for (var i = 0; i < startOffset; i++)
            cells.push({ day: 0, selected: false, today: false, disabled: false });

        for (var d = 1; d <= daysInMonth; d++) {
            var mm = viewMonth < 10 ? "0" + viewMonth : "" + viewMonth;
            var ds = d < 10 ? "0" + d : "" + d;
            var dateStr = viewYear + "-" + mm + "-" + ds;
            var isDisabled = (minDateVal !== "" && dateStr < minDateVal);
            cells.push({
                day: d,
                selected: dateStr === selectedDate,
                today: dateStr === todayStr,
                disabled: isDisabled
            });
        }

        while (cells.length < 42)
            cells.push({ day: 0, selected: false, today: false, disabled: false });

        return cells;
    }
}
