// The "Add a PC" card at the end of the Hosts row (docs/design/KIT.md): a flat
// card with an ash block, a red MANUAL label, a title and a mono caption.
import QtQuick
import DeckVoidTheme 1.0

Item {
    id: card
    property bool selected: false
    readonly property bool lifted: (!Theme.mouseMode && selected) || (Theme.mouseMode && hover.hovered)
    signal activated()
    signal selectRequested()

    // Focus: 2 px ink outline, 4 px offset
    Rectangle {
        anchors.fill: body
        anchors.margins: -6
        radius: Theme.radiusCard + 4
        color: "transparent"
        border.width: 2
        border.color: Theme.ink
        visible: card.lifted
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.radiusCard
        color: Theme.bone
        border.width: 1
        border.color: Theme.cardRule
        clip: true

        Rectangle {
            id: block
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
            height: Math.round(parent.height * 0.5)
            color: Theme.ash
            Text {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 18; bottomMargin: 6 }
                text: "+"
                color: Theme.ink
                font.family: Theme.sansFont
                font.weight: Font.Light
                font.pixelSize: 96
                lineHeight: 0.8
            }
        }

        Column {
            anchors { left: parent.left; right: parent.right; top: block.bottom; margins: 18 }
            spacing: 0
            Rectangle {
                width: manualText.implicitWidth + 14; height: 20
                color: Theme.vermilion
                Text { id: manualText; anchors.centerIn: parent; text: qsTr("MANUAL"); color: Theme.bone; font.family: Theme.monoFont; font.pixelSize: 11 }
            }
            Item { width: 1; height: 10 }
            Text { text: qsTr("Add a PC"); color: Theme.ink; font.family: Theme.sansFont; font.weight: Font.Bold; font.pixelSize: 20; font.letterSpacing: -0.4 }
            Item { width: 1; height: 4 }
            Text { width: parent.width; text: qsTr("by name or IP address"); color: Theme.stone; font.family: Theme.monoFont; font.pixelSize: 12; elide: Text.ElideRight }
        }

        Text {
            anchors { right: parent.right; bottom: parent.bottom; margins: 16 }
            text: "→"
            color: Theme.ink
            font.family: Theme.sansFont
            font.pixelSize: 18
        }
    }

    HoverHandler { id: hover; onHoveredChanged: if (hovered && Theme.mouseMode) card.selectRequested() }
    TapHandler { onTapped: { card.selectRequested(); card.activated() } }
}
