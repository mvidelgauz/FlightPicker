import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: columnRoot
    property int columnIndex: 0
    property var model: null

    // Which item index is at the highlight row
    property int selectedIndex: {
        if (!model || model.count === 0) return -1;
        // The highlight row's center in flickable coordinates
        var highlightCenter = flick.contentY + root.highlightRow * root.cellHeight + root.cellHeight / 2;
        // Which item does that fall on? Items start at topPadding.
        var idx = Math.floor((highlightCenter - topPadding) / root.cellHeight);
        return Math.max(0, Math.min(idx, model.count - 1));
    }

    property var selectedFlight: {
        var idx = selectedIndex;
        if (idx < 0 || !model || idx >= model.count) return null;
        var item = model.get(idx);
        if (!item) return null;
        return {
            airline: item.airline || "",
            flightNo: item.flightNo || "",
            aircraft: item.aircraft || "",
            dep: item.dep || "",
            arr: item.arr || "",
            depDate: item.depDate || "",
            depTime: item.depTime || "",
            arrDate: item.arrDate || "",
            arrTime: item.arrTime || "",
            duration: item.duration || "",
            price: item.price || ""
        };
    }

    // Top padding = space above first card so it can reach the highlight row
    property real topPadding: root.highlightRow * root.cellHeight
    // Bottom padding = space below last card so it can reach the highlight row
    property real bottomPadding: Math.max(0, columnRoot.height - (root.highlightRow + 1) * root.cellHeight)

    // Total content height
    property real totalContentHeight: topPadding + (model ? model.count : 0) * root.cellHeight + bottomPadding

    function scrollToIndex(idx) {
        if (!model) return;
        idx = Math.max(0, Math.min(idx, model.count - 1));
        snapAnim.to = idx * root.cellHeight;
        snapAnim.restart();
    }

    NumberAnimation {
        id: snapAnim
        target: flick
        property: "contentY"
        duration: 150
        easing.type: Easing.OutQuad
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: columnRoot.totalContentHeight
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1500
        maximumFlickVelocity: 2000

        // Snap to nearest item when flicking ends
        onMovementEnded: {
            var targetIdx = Math.round(contentY / root.cellHeight);
            if (model) targetIdx = Math.max(0, Math.min(targetIdx, model.count - 1));
            snapAnim.to = targetIdx * root.cellHeight;
            snapAnim.restart();
        }

        Column {
            id: cardColumn
            width: parent.width

            // Top spacer
            Item { width: 1; height: columnRoot.topPadding }

            // Flight cards
            Repeater {
                model: columnRoot.model

                Item {
                    id: cardItem
                    width: cardColumn.width
                    height: root.cellHeight
                    property bool isSelected: index === columnRoot.selectedIndex
                    property bool isHovered: cardMA.containsMouse

                    Rectangle {
                        anchors.fill: parent; anchors.margins: 2
                        radius: theme.borderRadius
                        color: cardItem.isSelected ? theme.cardSelectedBg : theme.cardBg
                        border.color: cardItem.isSelected ? theme.accent : theme.cardBorderCol
                        border.width: cardItem.isSelected ? 1.5 : theme.cardBorderW
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        // Airline accent bar
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top; anchors.bottom: parent.bottom
                            anchors.topMargin: 4; anchors.bottomMargin: 4
                            width: 3; radius: 2
                            color: root.airlineColor(model.airline)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12; anchors.rightMargin: 24
                            anchors.topMargin: 3; anchors.bottomMargin: 3
                            spacing: 0

                            // Row 1: year on each side
                            RowLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: model.depDate ? model.depDate.substring(0, 4) : ""; font.pixelSize: 8; font.family: theme.fontFamily; color: theme.textSecondary }
                                Item { Layout.fillWidth: true }
                                Text { text: model.arrDate ? model.arrDate.substring(0, 4) : ""; font.pixelSize: 8; font.family: theme.fontFamily; color: theme.textSecondary }
                            }
                            // Row 2: bold month-day on sides, airline + flight centered
                            RowLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text {
                                    text: model.depDate ? model.depDate.substring(5) : ""
                                    font.pixelSize: 11; font.weight: Font.Bold
                                    font.family: theme.fontFamily; color: theme.textSecondary
                                }
                                Item { Layout.fillWidth: true }
                                Text { text: model.airline; font.pixelSize: 10; font.weight: Font.DemiBold; font.family: theme.fontFamily; color: root.airlineColor(model.airline) }
                                Text { text: model.flightNo; font.pixelSize: 11; font.weight: Font.Bold; font.family: theme.fontFamily; color: cardItem.isSelected ? theme.textPrimary : theme.textSecondary }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: model.arrDate ? model.arrDate.substring(5) : ""
                                    font.pixelSize: 11; font.weight: Font.Bold
                                    font.family: theme.fontFamily; color: theme.textSecondary
                                }
                            }
                            // Row 3: times + duration
                            RowLayout {
                                Layout.fillWidth: true; spacing: 3
                                Text { text: model.depTime; font.pixelSize: 17; font.weight: Font.Bold; font.family: theme.fontFamily; color: theme.textPrimary }
                                Column {
                                    Layout.fillWidth: true; spacing: 0
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: model.duration; font.pixelSize: 8; font.family: theme.fontFamily; color: theme.textSecondary
                                    }
                                    Item {
                                        width: parent.width; height: 7
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left; anchors.right: parent.right
                                            anchors.leftMargin: 4; anchors.rightMargin: 4
                                            height: 1; color: theme.divider
                                        }
                                        Text {
                                            anchors.centerIn: parent; text: "✈"
                                            font.pixelSize: 7; color: theme.textSecondary; rotation: 90
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: model.dep + " → " + model.arr
                                        font.pixelSize: 8; font.letterSpacing: 1
                                        font.family: theme.fontFamily; color: theme.textSecondary
                                    }
                                }
                                Text { text: model.arrTime; font.pixelSize: 17; font.weight: Font.Bold; font.family: theme.fontFamily; color: theme.textPrimary }
                            }
                            // Row 4: aircraft + price
                            RowLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: model.aircraft; font.pixelSize: 8; font.family: theme.fontFamily; color: theme.textSecondary; opacity: 0.7 }
                                Item { Layout.fillWidth: true }
                                Text { text: model.price; font.pixelSize: 11; font.weight: Font.Bold; font.family: theme.fontFamily; color: cardItem.isSelected ? theme.accent : theme.textPrimary; visible: model.price !== "" }
                            }
                        }
                    }

                    // Single MouseArea handles hover + click + double-click.
                    // It does NOT set preventStealing, so the Flickable can still
                    // grab the gesture for scrolling when the user drags.
                    MouseArea {
                        id: cardMA
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: columnRoot.scrollToIndex(index)
                        onDoubleClicked: root.openEditDialog(columnRoot.columnIndex, index)
                    }

                    // Delete X button (above cardMA via z-order)
                    Rectangle {
                        anchors.top: parent.top; anchors.right: parent.right
                        anchors.topMargin: 5; anchors.rightMargin: 5
                        width: 18; height: 18; radius: 9
                        z: 10
                        visible: cardItem.isHovered
                        color: xMA.containsMouse ? theme.dangerBg : (darkMode ? "#2a3550" : "#d0d0d0")

                        Text {
                            anchors.centerIn: parent; text: "✕"
                            font.pixelSize: 9; font.weight: Font.Bold
                            color: xMA.containsMouse ? "#ffffff" : theme.textSecondary
                        }

                        MouseArea {
                            id: xMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                root.removeCard(columnRoot.columnIndex, index);
                                mouse.accepted = true;
                            }
                        }
                    }
                }
            }

            // Bottom spacer
            Item { width: 1; height: columnRoot.bottomPadding }
        }
    }
}
