// One PC on the Hosts screen (docs/design/KIT.md). A flat horizontal card: a
// colour block with the PC's number on the left, then a status label, the name,
// host software and address, and what is running.
import QtQuick
import DeckVoidTheme 1.0

Item {
    id: card

    // Host data (from ComputerModel)
    property string name
    property bool online
    property bool paired
    property bool statusUnknown
    property bool wakeable
    property string hostKind
    property string runningApp
    property string address
    property int number: 1

    // Selection: keyboard/controller focus, or the mouse hovering over the card.
    property bool selected: false
    readonly property bool hovered: hover.hovered
    readonly property bool lifted: (!Theme.mouseMode && selected) || (Theme.mouseMode && hovered)

    signal activated()        // A / Return / click: open apps, pair, or wake
    signal pairRequested()    // X: pair with a PIN
    signal wakeRequested()    // Y: wake
    signal menuRequested()    // ≡ / right click
    signal selectRequested()  // pointer interaction: make this the selected PC

    readonly property string status: statusUnknown ? "checking"
                                   : (online ? (paired ? "ready" : "pairing") : "asleep")
    // Block colour: moss when ready, vermilion when it needs pairing, stone otherwise.
    readonly property color blockColor: status === "ready" ? Theme.moss
                                      : status === "pairing" ? Theme.vermilion : Theme.stone
    readonly property string statusLabel: status === "ready" ? qsTr("ONLINE · PAIRED")
                                        : status === "pairing" ? qsTr("ONLINE · NOT PAIRED")
                                        : status === "checking" ? qsTr("CHECKING")
                                        : (wakeable ? qsTr("ASLEEP") : qsTr("OFFLINE"))
    readonly property string actionText: status === "ready" ? qsTr("Open apps")
                                       : status === "pairing" ? qsTr("Pair")
                                       : (status === "asleep" && wakeable ? qsTr("Wake") : "")
    readonly property string caption: {
        var parts = []
        if (hostKind !== "") parts.push(hostKind)
        if (address !== "") parts.push(address)
        return parts.join(" · ")
    }

    readonly property real preferredHeight: 236
    implicitHeight: preferredHeight

    // Focus: 2 px ink outline, 4 px offset, square corners. No glow, no lift.
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
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1 }
            width: Math.min(210, Math.round(parent.width * 0.35))
            color: card.blockColor
            Text {
                anchors { left: parent.left; top: parent.top; margins: 16 }
                text: qsTr("PC")
                color: Theme.bone
                font.family: Theme.monoFont
                font.pixelSize: 12
            }
            Text {
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 14; bottomMargin: 8 }
                text: (card.number < 10 ? "0" : "") + card.number
                color: Theme.bone
                font.family: Theme.sansFont
                font.weight: Font.Bold
                font.pixelSize: 120
                font.letterSpacing: -6
                lineHeight: 0.75
            }
        }

        Column {
            anchors { left: block.right; right: parent.right; top: parent.top; margins: 20 }
            spacing: 0

            Rectangle {
                width: statusText.implicitWidth + 14; height: 20
                color: card.status === "ready" ? Theme.ink : card.blockColor
                Text { id: statusText; anchors.centerIn: parent; text: card.statusLabel; color: Theme.bone; font.family: Theme.monoFont; font.pixelSize: 11 }
            }
            Item { width: 1; height: 12 }
            Text {
                width: parent.width
                text: card.name
                color: Theme.ink
                font.family: Theme.sansFont
                font.weight: Font.Bold
                font.pixelSize: 30
                font.letterSpacing: -0.9
                elide: Text.ElideRight
            }
            Item { width: 1; height: 8 }
            Text {
                width: parent.width
                text: card.caption
                color: Theme.stone
                font.family: Theme.monoFont
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        // Bottom line: what's running (marigold label), and the action as a text link
        Item {
            anchors { left: block.right; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 16; bottomMargin: 16 }
            height: 34
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.rule }
            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                spacing: 8
                visible: card.runningApp !== ""
                Rectangle {
                    width: runText.implicitWidth + 14; height: 20
                    color: Theme.marigold
                    Text { id: runText; anchors.centerIn: parent; text: qsTr("RUNNING"); color: Theme.ink; font.family: Theme.monoFont; font.pixelSize: 11 }
                }
                Text { text: card.runningApp; color: Theme.ink; font.family: Theme.sansFont; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                id: actionLink
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: card.actionText !== "" ? card.actionText + "  →" : "→"
                color: Theme.ink
                font.family: Theme.sansFont
                font.weight: Font.Medium
                font.pixelSize: 15
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.status === "asleep" ? card.wakeRequested() : card.activated()
                }
            }
        }
    }

    HoverHandler { id: hover; onHoveredChanged: if (hovered && Theme.mouseMode) card.selectRequested() }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: { card.selectRequested(); if (!Theme.touchMode) card.activated() }
        onLongPressed: card.menuRequested()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: card.menuRequested()
    }
}
