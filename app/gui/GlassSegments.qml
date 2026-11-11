import QtQuick 2.15
import DeckVoidTheme 1.0

// A choice shown as a row of labels in one pill, the current one dark. Every label
// has the same padding, so the control is as wide as its labels need.
Rectangle {
    id: segments
    property var options: []
    property int current: -1
    property real cq: 12
    signal picked(int index)

    width: row.width + 0.6 * cq
    height: row.height + 0.6 * cq
    radius: height / 2
    color: "#FFFFFF"
    border.width: 1
    border.color: Theme.glassPillBorder

    Row {
        id: row
        x: 0.3 * segments.cq
        y: 0.3 * segments.cq
        Repeater {
            model: segments.options
            delegate: Rectangle {
                readonly property bool active: index === segments.current
                width: label.implicitWidth + 2 * segments.cq
                height: label.implicitHeight + 0.9 * segments.cq
                radius: height / 2
                color: active ? Theme.glassText : "transparent"
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData
                    color: parent.active ? "#FFFFFF" : Theme.glassFaint
                    font.family: Theme.sansFont
                    font.pixelSize: 1.6 * segments.cq
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: segments.picked(index) }
            }
        }
    }
}
