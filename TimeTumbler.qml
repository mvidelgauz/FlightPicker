import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: tb
    radius: theme.borderRadius; color: theme.inputBg
    border.color: theme.inputBorder; border.width: 1

    property int maxVal: 23
    property int step: 1
    property bool isMinute: false
    property alias currentIndex: tb._val
    property int _val: 0

    function displayVal() { var v = isMinute ? _val * 5 : _val; return v < 10 ? "0" + v : "" + v; }
    function inc() { _val = (_val + step) > maxVal ? 0 : _val + step; }
    function dec() { _val = (_val - step) < 0 ? maxVal : _val - step; }

    RowLayout {
        anchors.fill: parent; anchors.margins: 1; spacing: 0
        Text {
            Layout.fillWidth: true; text: tb.displayVal()
            font.pixelSize: 12; font.weight: Font.DemiBold; font.family: theme.fontFamily
            color: theme.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        Column {
            Layout.preferredWidth: 14; Layout.fillHeight: true; spacing: 0
            Rectangle {
                width: 14; height: parent.height / 2
                color: upMA.containsMouse ? theme.divider : "transparent"
                Text { anchors.centerIn: parent; text: "▴"; font.pixelSize: 8; color: theme.textSecondary }
                MouseArea { id: upMA; anchors.fill: parent; hoverEnabled: true; onClicked: tb.inc() }
            }
            Rectangle {
                width: 14; height: parent.height / 2
                color: dnMA.containsMouse ? theme.divider : "transparent"
                Text { anchors.centerIn: parent; text: "▾"; font.pixelSize: 8; color: theme.textSecondary }
                MouseArea { id: dnMA; anchors.fill: parent; hoverEnabled: true; onClicked: tb.dec() }
            }
        }
    }
    MouseArea {
        anchors.fill: parent; propagateComposedEvents: true; acceptedButtons: Qt.NoButton
        onWheel: function(wheel) { if (wheel.angleDelta.y > 0) tb.inc(); else tb.dec(); }
    }
}
