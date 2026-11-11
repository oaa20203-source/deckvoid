import QtQuick 2.15
import QtQuick.Controls 2.15

import ComputerModel 1.0
import DeckVoidTheme 1.0

// Pairing: the whole window is glass, with the PIN to type on the PC in a card
// (design/mockups/pair.html). Pairing itself is started by the caller; this page
// closes when the PC answers.
Item {
    id: pairView
    objectName: qsTr("Pair")

    property ComputerModel computerModel
    property string pcName: ""
    property string pin: "0000"

    readonly property real cq: Math.min(width, height * 1.6) / 100

    function leave() {
        // Pairing cannot be interrupted once started; leaving only hides it
        stackView.pop()
    }

    Connections {
        target: pairView.computerModel
        function onPairingCompleted(error) {
            if (pairView.StackView.status !== StackView.Active) {
                return
            }
            stackView.pop()
            if (error !== undefined && error !== null && error !== "") {
                streamSegueErrorDialog.text = error
                streamSegueErrorDialog.open()
            }
        }
    }

    Keys.onEscapePressed: leave()

    FlutedGlass {
        anchors.fill: parent
        variant: 3
        fluteWidth: 1.6 * pairView.cq
    }

    // Home, under the window's close, minimise and maximise buttons
    Rectangle {
        x: 1.8 * cq
        y: 4.4 * cq
        width: homeLabel.implicitWidth + 3.6 * cq
        height: homeLabel.implicitHeight + 1.6 * cq
        radius: height / 2
        color: Qt.rgba(1, 1, 1, homeArea.containsMouse ? 1 : 0.85)
        Text {
            id: homeLabel
            anchors.centerIn: parent
            text: "←  " + qsTr("Home")
            color: Theme.glassText
            font.family: Theme.sansFont
            font.pixelSize: 1.9 * cq
        }
        MouseArea { id: homeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pairView.leave() }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 44 * cq
        height: cardColumn.implicitHeight + 5 * cq
        radius: 2.2 * cq
        color: Theme.glassPanel

        Column {
            id: cardColumn
            anchors.horizontalCenter: parent.horizontalCenter
            y: 2.4 * cq
            width: parent.width - 6 * cq

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Pairing with %1").arg(pairView.pcName)
                color: Theme.glassMuted
                font.family: Theme.sansFont
                font.pixelSize: 1.6 * cq
                elide: Text.ElideRight
            }
            Item { width: 1; height: 0.4 * cq }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Enter this PIN on your PC")
                color: Theme.glassText
                font.family: Theme.sansFont
                font.weight: Font.Medium
                font.pixelSize: 3 * cq
                font.letterSpacing: -0.025 * 3 * cq
            }
            Item { width: 1; height: 1.8 * cq }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1.2 * cq
                Repeater {
                    model: pairView.pin.length
                    delegate: Rectangle {
                        width: 6 * cq
                        height: 7.2 * cq
                        radius: 1.4 * cq
                        color: "#FFFFFF"
                        border.width: 1
                        border.color: Theme.glassPillBorder
                        Text {
                            anchors.centerIn: parent
                            text: pairView.pin.charAt(index)
                            color: Theme.glassText
                            font.family: Theme.sansFont
                            font.weight: Font.Medium
                            font.pixelSize: 3.8 * cq
                        }
                    }
                }
            }
            Item { width: 1; height: 1.8 * cq }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Type it into the Apollo, Vibepollo or Sunshine page on the PC.")
                color: Theme.glassMuted
                font.family: Theme.sansFont
                font.pixelSize: 1.6 * cq
            }
            Item { width: 1; height: 1.2 * cq }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Waiting for the PC…")
                color: Theme.glassText
                font.family: Theme.sansFont
                font.pixelSize: 1.6 * cq
            }
            Item { width: 1; height: 1.6 * cq }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: cancelLabel.implicitWidth + 3.8 * cq
                height: cancelLabel.implicitHeight + 1.5 * cq
                radius: height / 2
                color: cancelArea.containsMouse ? Theme.glassPanel : "#FFFFFF"
                border.width: 1
                border.color: Theme.glassPillBorder
                Text {
                    id: cancelLabel
                    anchors.centerIn: parent
                    text: qsTr("Cancel")
                    color: Theme.glassText
                    font.family: Theme.sansFont
                    font.pixelSize: 1.6 * cq
                }
                MouseArea { id: cancelArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pairView.leave() }
            }
        }
    }
}
