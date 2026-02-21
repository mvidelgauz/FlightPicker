import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Custom editable combo: a TextField with a dropdown arrow button.
// The popup is parented to Overlay.overlay so it's never clipped.

Item {
    id: ecb
    height: 26

    property var model: []
    property string editText: ""
    property string placeholderText: ""

    // Background
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: theme.borderRadius
        color: theme.inputBg
        border.color: textField.activeFocus ? theme.inputFocusBorder : theme.inputBorder
        border.width: textField.activeFocus ? 1.5 : 1
    }

    // Text input area
    TextField {
        id: textField
        anchors.left: parent.left
        anchors.right: arrowBtn.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        text: ecb.editText
        placeholderText: ecb.placeholderText
        placeholderTextColor: theme.textSecondary
        font.pixelSize: 11; font.family: theme.fontFamily
        color: theme.textPrimary
        selectByMouse: true
        leftPadding: 6; rightPadding: 2
        topPadding: 3; bottomPadding: 3
        background: Item {}

        onTextEdited: ecb.editText = text
        onTextChanged: {
            if (text !== ecb.editText) ecb.editText = text;
        }

        Keys.onDownPressed: openDropdown()
        Keys.onEscapePressed: dropdownPopup.close()
    }

    onEditTextChanged: {
        if (textField.text !== editText) textField.text = editText;
    }

    // Arrow dropdown button
    Rectangle {
        id: arrowBtn
        anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        width: 20
        color: arrowMA.containsMouse ? theme.calendarDayHover : "transparent"
        radius: theme.borderRadius

        Text {
            anchors.centerIn: parent
            text: "▾"; font.pixelSize: 11; color: theme.textSecondary
        }

        MouseArea {
            id: arrowMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (dropdownPopup.visible)
                    dropdownPopup.close();
                else
                    openDropdown();
            }
        }
    }

    function openDropdown() {
        // Build filtered items BEFORE computing popup height
        var items = getFilteredItems();
        filteredModel = items;

        var globalPos = ecb.mapToGlobal(0, 0);
        var windowPos = root.contentItem.mapFromGlobal(globalPos.x, globalPos.y);

        dropdownPopup.width = Math.max(ecb.width, 160);

        // Compute height based on actual item count, not contentHeight
        var itemCount = items.length;
        var popupH = Math.min(itemCount * 30 + 6, 250);
        if (popupH < 36) popupH = 36; // Minimum height
        dropdownPopup.height = popupH;

        // Open upward
        var yUp = windowPos.y - popupH - 2;
        if (yUp >= 0) {
            dropdownPopup.y = yUp;
        } else {
            dropdownPopup.y = windowPos.y + ecb.height + 2;
        }
        dropdownPopup.x = windowPos.x;
        dropdownPopup.open();
    }

    // Filtered items stored as a property so the ListView model updates
    property var filteredModel: []

    function getFilteredItems() {
        var items = [];
        var src = ecb.model;
        if (!src || !src.length) return items;
        var filter = ecb.editText.toLowerCase().trim();
        for (var i = 0; i < src.length; i++) {
            var item = "" + src[i];
            if (item === "" || item === "undefined") continue;
            if (filter === "" || item.toLowerCase().indexOf(filter) >= 0) {
                items.push(item);
            }
        }
        return items;
    }

    Popup {
        id: dropdownPopup
        parent: Overlay.overlay
        modal: false; focus: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 2

        background: Rectangle {
            color: theme.inputBg
            border.color: theme.accent
            border.width: 1
            radius: theme.borderRadius
        }

        contentItem: ListView {
            id: filteredListView
            clip: true
            model: ecb.filteredModel

            delegate: Rectangle {
                width: filteredListView.width
                height: 30
                color: delegateMA.containsMouse ? theme.accent : "transparent"
                radius: 2

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 8
                    text: modelData
                    font.pixelSize: 11; font.family: theme.fontFamily
                    color: delegateMA.containsMouse ? theme.buttonText : theme.textPrimary
                }

                MouseArea {
                    id: delegateMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ecb.editText = modelData;
                        dropdownPopup.close();
                    }
                }
            }

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        }
    }
}
