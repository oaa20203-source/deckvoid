import QtQuick 2.15
import DeckVoidTheme 1.0

// An on/off switch: dark when on (design/mockups/settings.html)
Rectangle {
    id: toggle
    property bool on: false
    property real cq: 12
    signal toggled()

    width: 3.2 * cq
    height: 1.8 * cq
    radius: height / 2
    color: on ? Theme.glassText : Theme.glassTrack

    Rectangle {
        width: 1.3 * toggle.cq
        height: width
        radius: width / 2
        y: 0.25 * toggle.cq
        x: toggle.on ? parent.width - width - 0.25 * toggle.cq : 0.25 * toggle.cq
        color: "#FFFFFF"
        Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -0.6 * toggle.cq
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
