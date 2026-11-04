import QtQuick 2.0
import QtQuick.Controls 2.2
import DeckVoidTheme 1.0

// App tile: a white rounded card; focused (or hovered with a mouse) it lifts
// slightly with a soft mango glow, matching the host cards.
ItemDelegate {
    id: tile
    property GridView grid
    readonly property bool lifted: highlighted || (Theme.mouseMode && hovered)

    highlighted: grid.activeFocus && grid.currentItem === this
    transform: Translate { y: tile.lifted ? (Theme.mouseMode ? -4 : -6) : 0 }
    scale: tile.highlighted && Theme.controllerMode ? 1.04 : 1.0
    Behavior on scale { NumberAnimation { duration: 120 } }

    background: Item {
        Rectangle {
            // glow
            anchors.fill: card
            anchors.margins: -4
            radius: card.radius + 4
            color: "transparent"
            border.width: 4
            border.color: Theme.glow
            visible: tile.lifted
        }
        Rectangle {
            id: card
            anchors.fill: parent
            radius: 22
            color: Theme.surface
            border.width: tile.lifted ? 1.5 : 1
            border.color: tile.lifted ? Theme.accent : Theme.line
        }
    }

    Keys.onLeftPressed: {
        grid.moveCurrentIndexLeft()
    }
    Keys.onRightPressed: {
        grid.moveCurrentIndexRight()
    }
    Keys.onDownPressed: {
        grid.moveCurrentIndexDown()
    }
    Keys.onUpPressed: {
        grid.moveCurrentIndexUp()

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
