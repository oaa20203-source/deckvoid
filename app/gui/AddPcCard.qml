// The dashed "Add a PC" card at the end of the Hosts grid.
import QtQuick
import QtQuick.Shapes
import DeckVoidTheme 1.0

Item {
    id: card
    property bool selected: false
    readonly property bool lifted: (Theme.controllerMode && selected) || (Theme.mouseMode && hover.hovered)
    signal activated()
    signal selectRequested()

    transform: Translate { y: card.lifted ? (Theme.controllerMode ? -6 : -4) : 0
                           Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } } }
    scale: Theme.controllerMode && card.lifted ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Theme.radiusCard + 4
        color: "transparent"
        border.width: 4
        border.color: Theme.glow
        visible: card.lifted
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: card.lifted ? Theme.accent : Theme.dashed
            strokeWidth: 2.5
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            fillColor: card.lifted ? Theme.accentTint : "transparent"
            PathRectangle {
                x: 1.25; y: 1.25
                width: card.width - 2.5; height: card.height - 2.5
                radius: Theme.radiusCard
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 10
        Item {
            width: 48; height: 48
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle { anchors.centerIn: parent; width: 44; height: 5; radius: 2; color: Theme.accentDeep }
            Rectangle { anchors.centerIn: parent; width: 5; height: 44; radius: 2; color: Theme.accentDeep }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Add a PC")
            color: Theme.text
            font.family: Theme.headingFont
            font.weight: Font.Bold
            font.pixelSize: Theme.cardTitle
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("By IP address")
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.weight: Font.Medium
            font.pixelSize: Theme.meta
        }
    }

    HoverHandler { id: hover; onHoveredChanged: if (hovered && Theme.mouseMode) card.selectRequested() }
    TapHandler { onTapped: { card.selectRequested(); card.activated() } }
}
