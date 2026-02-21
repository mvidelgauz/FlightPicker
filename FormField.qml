import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
    id: field; height: 26
    font.pixelSize: 11; font.family: theme.fontFamily
    color: theme.textPrimary
    placeholderTextColor: Qt.darker(theme.textSecondary, 1.15)
    selectByMouse: true
    leftPadding: 6; rightPadding: 6; topPadding: 3; bottomPadding: 3
    background: Rectangle {
        radius: theme.borderRadius; color: theme.inputBg
        border.color: field.activeFocus ? theme.inputFocusBorder : theme.inputBorder
        border.width: field.activeFocus ? 1.5 : 1
    }
}
