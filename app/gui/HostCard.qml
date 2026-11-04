// One PC on the Hosts screen (docs/design/DESIGN.md, mockups/*-hosts).
// Status is a coloured strip across the top plus a dot before the status word.
import QtQuick
import QtQuick.Effects
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

    // Selection: keyboard/controller focus, or the mouse hovering over the card.
    property bool selected: false
    readonly property bool hovered: hover.hovered
    readonly property bool lifted: (Theme.controllerMode && selected) || (Theme.mouseMode && hovered)

    signal activated()        // A / Return / click: open apps, pair, or wake
    signal pairRequested()    // X: pair with a PIN
    signal wakeRequested()    // Y: wake
    signal menuRequested()    // ≡ / right click / •••
    signal selectRequested()  // pointer interaction: make this the selected PC

    readonly property string status: statusUnknown ? "checking"
                                   : (online ? (paired ? "ready" : "pairing") : "asleep")
    readonly property color statusColor: status === "ready" ? Theme.statusReady
                                       : (status === "pairing" ? Theme.statusNeedsPairing : Theme.statusAsleep)
    readonly property string statusWord: status === "ready" ? qsTr("Streaming ready")
                                       : status === "pairing" ? qsTr("Needs pairing")
                                       : status === "checking" ? qsTr("Checking…")
                                       : (wakeable ? qsTr("Asleep") : qsTr("Offline"))

    readonly property string metaText: {
        var parts = []
        if (status === "ready") {
            parts.push(qsTr("Paired"))
            parts.push(hostKind)
            if (runningApp !== "") parts.push(runningApp)
        }
        else if (status === "pairing") {
            parts.push(qsTr("Online"))
            parts.push(hostKind)
            if (Theme.controllerMode) parts.push(qsTr("Press X to pair"))
            else if (Theme.touchMode) parts.push(qsTr("Tap Pair to use a PIN"))
            else parts.push(qsTr("Click to pair with a PIN"))
        }
        else if (status === "asleep") {
            parts.push(paired ? qsTr("Paired") : qsTr("Not paired"))
            if (hostKind !== "") parts.push(hostKind)
            if (wakeable) {
                if (Theme.controllerMode) parts.push(qsTr("Press Y to wake"))
                else if (Theme.touchMode) parts.push(qsTr("Tap Wake to start it"))
                else parts.push(qsTr("Click Wake to start it"))
            }
        }
        return parts.join(" · ")
    }

    // Action button for touch (always) and mouse (on hover).
    readonly property string actionText: status === "ready" ? qsTr("Stream")
                                       : status === "pairing" ? qsTr("Pair")
                                       : (status === "asleep" && wakeable ? qsTr("Wake") : "")
    readonly property bool showAction: actionText !== "" && (Theme.touchMode || (Theme.mouseMode && hovered))

    // Mouse and touch reserve a row at the bottom for the action buttons so they
    // never cover the text; the grid sizes every card to preferredHeight.
    readonly property bool reservesActionRow: Theme.mouseMode || Theme.touchMode
    readonly property real heroHeight: Math.round(width * (Theme.controllerMode ? 0.44 : 0.36))
    readonly property real actionRowHeight: Theme.mouseMode ? 36 : 48
    readonly property real preferredHeight: heroHeight + textBlock.anchors.topMargin + textBlock.implicitHeight
                                            + (reservesActionRow ? 14 + actionRowHeight : 0) + Theme.cardPadding + 4
    implicitHeight: preferredHeight

    // Focus / hover lift: scale and rise with a soft shadow and a thin mango glow.
    transform: Translate { y: card.lifted ? (Theme.controllerMode ? -6 : -4) : 0
                           Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } } }
    scale: Theme.controllerMode && card.lifted ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    z: lifted ? 2 : 1

    Rectangle {
        // Glow ring
        anchors.fill: body
        anchors.margins: -4
        radius: Theme.radiusCard + 4
        color: "transparent"
        border.width: 4
        border.color: Theme.glow
        visible: card.lifted
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.radiusCard
        color: Theme.surface
        border.width: 1
        border.color: Theme.line
        clip: true
        layer.enabled: card.lifted
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 1.0
            shadowVerticalOffset: 16
            shadowOpacity: 0.9
            autoPaddingEnabled: true
        }

        // Tinted top area with the monitor icon
        Item {
            id: hero
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: card.heroHeight
            readonly property color tint: card.status === "ready" ? Theme.accentTint : Theme.surfaceMuted
            // Rounded top corners that follow the card, square bottom edge
            Rectangle { anchors.fill: parent; radius: Theme.radiusCard; color: hero.tint }
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: Theme.radiusCard; color: hero.tint }

            MonitorIcon {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 4
                width: card.status === "ready" ? 76 : 64
                height: width * 0.86
                color: card.status === "ready" ? Theme.accentDeep : Theme.textMuted
                opacity: card.status === "asleep" || card.status === "checking" ? 0.6 : 1.0
            }
        }

        // Status strip across the top, following the card's rounded corners
        Item {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: Theme.statusStrip
            clip: true
            Rectangle { width: parent.width; height: Theme.radiusCard * 2; radius: Theme.radiusCard; color: card.statusColor }
        }

        Column {
            id: textBlock
            anchors { left: parent.left; right: parent.right; top: hero.bottom }
            anchors.leftMargin: Theme.cardPadding + 4
            anchors.rightMargin: Theme.cardPadding
            anchors.topMargin: 16
            spacing: 6

            Text {
                width: parent.width
                text: card.name
                color: Theme.text
                font.family: Theme.headingFont
                font.weight: Font.Bold
                font.pixelSize: Theme.cardTitle
                elide: Text.ElideRight
            }

            Row {
                spacing: 9
                Rectangle {
                    width: Theme.statusDot; height: Theme.statusDot; radius: width / 2
                    color: card.statusColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: card.statusWord
                    color: Theme.textStrong
                    font.family: Theme.bodyFont
                    font.weight: Font.DemiBold
                    font.pixelSize: Theme.body
                }
            }

            Text {
                width: parent.width
                text: card.metaText
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.Medium
                font.pixelSize: Theme.meta
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                // Always reserve two lines so every card has the same height.
                height: Math.ceil(fontInfo.pixelSize * 1.35) * 2
            }
        }

        // Mouse: action + ••• appear on hover. Touch: one big action button.
        Row {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.margins: Theme.cardPadding
            spacing: 12
            visible: card.showAction

            DvButton {
                width: parent.width - (moreButton.visible ? moreButton.width + parent.spacing : 0)
                text: card.actionText
                primary: card.status === "ready"
                onClicked: card.status === "asleep" ? card.wakeRequested() : card.activated()
            }
            Rectangle {
                id: moreButton
                visible: Theme.mouseMode
                width: 40; height: 36; radius: 18
                color: Theme.surface
                border.color: Theme.lineStrong; border.width: 1.5
                Text { anchors.centerIn: parent; text: "•••"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Bold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.menuRequested() }
            }
        }
    }

    HoverHandler { id: hover; onHoveredChanged: if (hovered && Theme.mouseMode) card.selectRequested() }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        // Touch uses the action button; a tap on the card body only selects it.
        onTapped: { card.selectRequested(); if (!Theme.touchMode) card.activated() }
        onLongPressed: card.menuRequested()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: card.menuRequested()
    }
}
