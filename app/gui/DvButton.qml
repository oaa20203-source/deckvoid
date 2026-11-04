// Kit button: vermilion fill with bone text (primary), or a plain outlined button.
import QtQuick
import DeckVoidTheme 1.0

Rectangle {
    id: button
    property string text
    property string shortcutHint: ""   // e.g. "⏎", shown in mouse mode
    property bool primary: true
    signal clicked()

    implicitHeight: Theme.mouseMode ? 36 : 48
    implicitWidth: label.implicitWidth + 48
    radius: Theme.radiusControl
    color: primary ? (area.pressed ? Qt.darker(Theme.accent, 1.06) : Theme.accent) : Theme.surface
    border.width: primary ? 0 : 1.5
    border.color: Theme.cardRule

    Row {
        anchors.centerIn: parent
        spacing: 10
        Text {
            id: label
            text: button.text
            color: button.primary ? Theme.accentText : Theme.text
            font.family: Theme.bodyFont
            font.weight: Font.Medium
            font.pixelSize: Theme.px(17)
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            visible: Theme.mouseMode && button.shortcutHint !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: hint.implicitWidth + 12; height: 20; radius: 5
            color: Qt.rgba(0, 0, 0, 0.08)
            Text { id: hint; anchors.centerIn: parent; text: button.shortcutHint; color: Theme.textSecondary; font.pixelSize: 12; font.family: Theme.bodyFont }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
