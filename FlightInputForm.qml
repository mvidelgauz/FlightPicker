import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: formRoot
    radius: theme.borderRadius; color: theme.cardBg
    border.color: theme.divider; border.width: 1

    property var segmentDepAirports: []
    property var segmentArrAirports: []
    property int defaultDepIdx: 0
    property int defaultArrIdx: 0
    signal addFlight(var data)

    property string depTimeStr: padZ(depHourTumbler.currentIndex) + ":" + padZ(depMinTumbler.currentIndex * 5)
    property string arrTimeStr: padZ(arrHourTumbler.currentIndex) + ":" + padZ(arrMinTumbler.currentIndex * 5)
    function padZ(n) { return n < 10 ? "0" + n : "" + n; }

    property string computedDuration: {
        var depAP = segmentDepAirports[cbDep.currentIndex] || "";
        var arrAP = segmentArrAirports[cbArr.currentIndex] || "";
        return root.calcDuration(depDatePicker.selectedDate, depTimeStr,
                                  arrDatePicker.selectedDate, arrTimeStr, depAP, arrAP);
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 7; spacing: 3

        Text {
            text: "Add Flight"; font.pixelSize: 10; font.weight: Font.DemiBold
            font.letterSpacing: 0.5; font.family: theme.fontFamily; color: theme.accent
        }

        // Airline + Flight No
        RowLayout {
            Layout.fillWidth: true; spacing: 3
            EditableCombo {
                id: cbAirline; Layout.fillWidth: true
                model: { root.airlineListVersion; return root.airlineList; }
                placeholderText: "Airline"
            }
            FormField { id: fFlightNo; Layout.preferredWidth: 65; placeholderText: "Flt #" }
        }

        // Aircraft + Price
        RowLayout {
            Layout.fillWidth: true; spacing: 3
            EditableCombo {
                id: cbAircraft; Layout.fillWidth: true
                model: { root.aircraftListVersion; return root.aircraftList; }
                placeholderText: "Aircraft"
            }
            FormField { id: fPrice; Layout.preferredWidth: 65; placeholderText: "Price $" }
        }

        // Dep → Arr airports
        RowLayout {
            Layout.fillWidth: true; spacing: 3
            StyledCombo {
                id: cbDep; Layout.fillWidth: true
                model: formRoot.segmentDepAirports
                currentIndex: formRoot.defaultDepIdx
            }
            Text { text: "→"; font.pixelSize: 14; color: theme.textSecondary; Layout.preferredWidth: 16; horizontalAlignment: Text.AlignHCenter }
            StyledCombo {
                id: cbArr; Layout.fillWidth: true
                model: formRoot.segmentArrAirports
                currentIndex: formRoot.defaultArrIdx
            }
        }

        // Dep date + time
        RowLayout {
            Layout.fillWidth: true; spacing: 3
            Text { text: "DEP"; font.pixelSize: 9; font.weight: Font.Bold; font.family: theme.fontFamily; color: theme.textSecondary; Layout.preferredWidth: 26 }
            DatePickerField { id: depDatePicker; Layout.fillWidth: true }
            TimeTumbler { id: depHourTumbler; Layout.preferredWidth: 38; Layout.preferredHeight: 26; maxVal: 23 }
            Text { text: ":"; font.pixelSize: 12; color: theme.textSecondary }
            TimeTumbler { id: depMinTumbler; Layout.preferredWidth: 38; Layout.preferredHeight: 26; maxVal: 11; isMinute: true }
        }

        // Arr date + time
        RowLayout {
            Layout.fillWidth: true; spacing: 3
            Text { text: "ARR"; font.pixelSize: 9; font.weight: Font.Bold; font.family: theme.fontFamily; color: theme.textSecondary; Layout.preferredWidth: 26 }
            DatePickerField { id: arrDatePicker; Layout.fillWidth: true; minDate: depDatePicker.selectedDate }
            TimeTumbler { id: arrHourTumbler; Layout.preferredWidth: 38; Layout.preferredHeight: 26; maxVal: 23 }
            Text { text: ":"; font.pixelSize: 12; color: theme.textSecondary }
            TimeTumbler { id: arrMinTumbler; Layout.preferredWidth: 38; Layout.preferredHeight: 26; maxVal: 11; isMinute: true }
        }

        // Duration + Add
        RowLayout {
            Layout.fillWidth: true; spacing: 3
            Text {
                text: computedDuration !== "" ? "Duration: " + computedDuration : "Duration: --"
                font.pixelSize: 10; font.family: theme.fontFamily; color: theme.textSecondary
                Layout.fillWidth: true
            }
            Rectangle {
                Layout.preferredWidth: 56; Layout.preferredHeight: 26
                radius: theme.borderRadius
                color: addMA.containsMouse ? theme.buttonHoverBg : theme.buttonBg
                Text { anchors.centerIn: parent; text: "Add"; font.pixelSize: 11; font.weight: Font.Bold; font.family: theme.fontFamily; color: theme.buttonText }
                MouseArea {
                    id: addMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var depCode = formRoot.segmentDepAirports[cbDep.currentIndex] || "";
                        var arrCode = formRoot.segmentArrAirports[cbArr.currentIndex] || "";
                        if (depCode === "" || arrCode === "") return;
                        var priceStr = fPrice.text.trim();
                        if (priceStr.length > 0 && priceStr[0] !== '$') priceStr = "$" + priceStr;

                        var alText = cbAirline.editText.trim();
                        var acText = cbAircraft.editText.trim();

                        // Dynamically add new airline/aircraft entries
                        if (alText !== "") {
                            root.airlineList = root.ensureInList(root.airlineList, alText);
                            root.airlineListVersion++;
                        }
                        if (acText !== "") {
                            root.aircraftList = root.ensureInList(root.aircraftList, acText);
                            root.aircraftListVersion++;
                        }

                        formRoot.addFlight({
                            airline: alText,
                            flightNo: fFlightNo.text.trim(),
                            dep: depCode, arr: arrCode,
                            depDate: depDatePicker.selectedDate,
                            depTime: formRoot.depTimeStr,
                            arrDate: arrDatePicker.selectedDate,
                            arrTime: formRoot.arrTimeStr,
                            duration: formRoot.computedDuration,
                            price: priceStr,
                            aircraft: acText
                        });

                        // Reset
                        cbAirline.editText = "";
                        fFlightNo.text = "";
                        cbAircraft.editText = "";
                        fPrice.text = "";
                        depDatePicker.selectedDate = "";
                        arrDatePicker.selectedDate = "";
                        depHourTumbler.currentIndex = 0; depMinTumbler.currentIndex = 0;
                        arrHourTumbler.currentIndex = 0; arrMinTumbler.currentIndex = 0;
                    }
                }
            }
        }
    }
}
