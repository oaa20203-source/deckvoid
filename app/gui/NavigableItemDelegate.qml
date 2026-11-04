import QtQuick 2.0
import QtQuick.Controls 2.2
import DeckVoidTheme 1.0

// App tile: a flat kit card (docs/design/KIT.md) with a focus outline.
ItemDelegate {
    id: tile
    // A GridView or a ListView (the Apps row)
    property Item grid
    // One outline at a time: hovering a card makes it the selected one
    readonly property bool lifted: highlighted
    onHoveredChanged: if (hovered && grid) grid.currentIndex = index

    // The selected card stays outlined even when the window is in the background (Figma)
    highlighted: grid.currentItem === this

    // Flat kit card; focus is a 2 px ink outline with a 4 px gap. No lift, no glow.
    background: Item {
        Rectangle {
            anchors.fill: card
            anchors.margins: -6
            radius: card.radius + 4
            color: "transparent"
            border.width: 2
            border.color: Theme.ink
            visible: tile.lifted
        }
        Rectangle {
            id: card
            anchors.fill: parent
            radius: Theme.radiusCard
            color: Theme.bone
            border.width: 1
            border.color: Theme.cardRule
        }
    }

    Keys.onLeftPressed: {
        if (grid.moveCurrentIndexLeft) grid.moveCurrentIndexLeft()
        else grid.decrementCurrentIndex()
    }
    Keys.onRightPressed: {
        if (grid.moveCurrentIndexRight) grid.moveCurrentIndexRight()
        else grid.incrementCurrentIndex()
    }
    Keys.onDownPressed: {
        if (grid.moveCurrentIndexDown) grid.moveCurrentIndexDown()
    }
    Keys.onUpPressed: {
        if (grid.moveCurrentIndexUp) grid.moveCurrentIndexUp()

        // If we've reached the top of the grid, move focus to the toolbar
        if (grid.currentItem === this) {
            nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        }
    }
    Keys.onReturnPressed: {
        clicked()
    }
    Keys.onEnterPressed: {
        clicked()
    }
}
