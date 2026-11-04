// Pill button: filled mango (primary) or outlined. Text is always the dark text colour.
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
    radius: height / 2
    color: primary ? (area.pressed ? Qt.darker(Theme.accent, 1.06) : Theme.accent) : Theme.surface
    border.width: primary ? 0 : 1.5
    border.color: Theme.lineStrong

    Row {
        anchors.centerIn: parent
        spacing: 10
        Text {
            id: label
            text: button.text
            color: Theme.text
            font.family: Theme.bodyFont
            font.weight: Font.Bold
            font.pixelSize: Theme.px(18)
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
