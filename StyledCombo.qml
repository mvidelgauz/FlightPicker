import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Non-editable styled combo for airport selection.
// Popup parented to Overlay.overlay to avoid clipping.

Item {
    id: sc
    height: 26

    property var model: []
    property int currentIndex: 0
    property string displayText: (currentIndex >= 0 && currentIndex < model.length)
                                  ? model[currentIndex] : ""

    Rectangle {
        anchors.fill: parent
        radius: theme.borderRadius
        color: theme.inputBg
        border.color: theme.inputBorder; border.width: 1

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6; rightPadding: 22
            width: parent.width - 22
            text: sc.displayText
            font.pixelSize: 11; font.family: theme.fontFamily
            color: sc.currentIndex >= 0 ? theme.textPrimary : theme.textSecondary
            elide: Text.ElideRight
        }

        Text {
            anchors.right: parent.right; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"; font.pixelSize: 10; color: theme.textSecondary
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (scPopup.visible) scPopup.close();
                else openPopup();
            }
        }
    }

    function openPopup() {
        var globalPos = sc.mapToGlobal(0, 0);
        var windowPos = root.contentItem.mapFromGlobal(globalPos.x, globalPos.y);

        scPopup.width = sc.width;
        var popH = Math.min(sc.model.length * 30 + 4, 220);
        scPopup.height = popH;

        var yUp = windowPos.y - popH - 2;
        if (yUp >= 0) {
            scPopup.y = yUp;
        } else {
            scPopup.y = windowPos.y + sc.height + 2;
        }
        scPopup.x = windowPos.x;
        scPopup.open();
    }

    Popup {
        id: scPopup
        parent: Overlay.overlay
        modal: false; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 2

        background: Rectangle {
            color: theme.inputBg; border.color: theme.accent
            border.width: 1; radius: theme.borderRadius
        }

        contentItem: ListView {
            id: scListView
            clip: true
            implicitHeight: Math.min(contentHeight, 210)
            model: scPopup.visible ? sc.model : []

            delegate: Rectangle {
                width: scListView.width; height: 30
                radius: 2
                color: {
                    if (index === sc.currentIndex && !scDelMA.containsMouse)
                        return theme.calendarToday;
                    if (scDelMA.containsMouse) return theme.accent;
                    return "transparent";
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 8
                    text: modelData
                    font.pixelSize: 11; font.family: theme.fontFamily
                    font.weight: index === sc.currentIndex ? Font.Bold : Font.Normal
                    color: scDelMA.containsMouse ? theme.buttonText : theme.textPrimary
                }

                MouseArea {
                    id: scDelMA; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        sc.currentIndex = index;
                        scPopup.close();
                    }
                }
            }

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
