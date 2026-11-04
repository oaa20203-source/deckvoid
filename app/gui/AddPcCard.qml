// The "Add a PC" card at the end of the Hosts row (docs/design/KIT.md): a flat
// card with an ash block, a red MANUAL label, a title and a mono caption.
import QtQuick
import DeckVoidTheme 1.0

Item {
    id: card
    property bool selected: false
    readonly property bool lifted: selected
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

        // Figma: 260 x 263, ash block 150 tall, text 19 px from the left
        Rectangle {
            id: block
            x: 1; y: 1
            width: parent.width - 2
            height: 150
            color: Theme.ash
            Text {
                x: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                text: "+"
                color: Theme.ink
                font.family: Theme.sansFont
                font.weight: Font.Light
                font.pixelSize: 96
                lineHeightMode: Text.FixedHeight
                lineHeight: 68
                verticalAlignment: Text.AlignBottom
            }
        }
        Rectangle {
            id: manualTag
            x: 19; y: 167
            width: manualText.implicitWidth + 14; height: 20
            color: Theme.vermilion
            Text { id: manualText; anchors.centerIn: parent; text: qsTr("MANUAL"); color: Theme.bone; font.family: Theme.monoFont; font.pixelSize: 11 }
        }
        Text { x: 19; y: 197; text: qsTr("Add a PC"); color: Theme.ink; font.family: Theme.sansFont; font.weight: Font.Bold; font.pixelSize: 20; font.letterSpacing: -0.4; lineHeightMode: Text.FixedHeight; lineHeight: 26 }
        Text { x: 19; y: 227; width: parent.width - 60; text: qsTr("by name or IP address"); color: Theme.stone; font.family: Theme.monoFont; font.pixelSize: 13; lineHeightMode: Text.FixedHeight; lineHeight: 17; elide: Text.ElideRight }
        Text {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 17; bottomMargin: 14 }
            text: "→"
            color: Theme.ink
            font.family: Theme.sansFont
            font.pixelSize: 18
        }
    }

    HoverHandler { id: hover; onHoveredChanged: if (hovered) card.selectRequested() }
    TapHandler { onTapped: { card.selectRequested(); card.activated() } }
}
