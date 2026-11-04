// Outline monitor icon from the redesign mockups, drawn so it can take any colour.
import QtQuick

Item {
    property color color: "#B36A1C"
    property real stroke: Math.max(3, width / 17)
    implicitWidth: 72
    implicitHeight: 62

    Rectangle {
        id: screen
        width: parent.width
        height: parent.height * 0.72
        radius: parent.stroke * 1.6
        color: "transparent"
        border.color: parent.color
        border.width: parent.stroke
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: screen.bottom
        width: parent.stroke
        height: parent.height * 0.16
        color: parent.color
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width * 0.42
        height: parent.stroke
        radius: height / 2
        color: parent.color
    }
}
