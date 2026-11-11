import QtQuick 2.15
import QtQuick.Controls 2.15

import ComputerManager 1.0
import DeckVoidTheme 1.0

// Add a PC by name or address: a card on a full window of glass, like pairing
Item {
    id: addView
    objectName: qsTr("Add a PC")

    readonly property real cq: Math.min(width, height * 1.6) / 100

    function leave() { stackView.pop() }
    function add() {
        var address = field.text.trim()
        if (address === "") {
            hint.wrong = true
            field.forceActiveFocus()
            return
        }
        ComputerManager.addNewHostManually(address)
        stackView.pop()
    }

    StackView.onActivated: field.forceActiveFocus()
    Keys.onEscapePressed: leave()

    FlutedGlass {
        anchors.fill: parent
        variant: 3
        seed: 1.3
        fluteWidth: 1.6 * addView.cq
        off: window.pcOff
    }

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
        MouseArea { id: homeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: addView.leave() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 44 * cq
        height: column.implicitHeight + 5 * cq
        radius: 2.2 * cq
        color: Theme.glassPanel

        Column {
            id: column
            anchors.horizontalCenter: parent.horizontalCenter
            y: 2.4 * cq
            width: parent.width - 6 * cq

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Add a PC")
                color: Theme.glassMuted
                font.family: Theme.sansFont
                font.pixelSize: 1.6 * cq
            }
            Item { width: 1; height: 0.4 * cq }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Enter its name or IP address")
                color: Theme.glassText
                font.family: Theme.sansFont
                font.weight: Font.Medium
                font.pixelSize: 3 * cq
                font.letterSpacing: -0.025 * 3 * cq
            }
            Item { width: 1; height: 1.8 * cq }
            Rectangle {
                width: parent.width
                height: 4.6 * cq
                radius: height / 2
                color: "#FFFFFF"
                border.width: field.activeFocus ? Math.max(1.5, 0.24 * cq) : 1
                border.color: field.activeFocus ? Theme.glassText : Theme.glassPillBorder
                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 1.8 * cq
                    anchors.rightMargin: 1.8 * cq
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.glassText
                    selectionColor: Theme.glassOrange
                    font.family: Theme.sansFont
                    font.pixelSize: 1.8 * cq
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    onTextEdited: hint.wrong = false
                    Keys.onReturnPressed: addView.add()
                    Keys.onEnterPressed: addView.add()
                    Text {
                        visible: field.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "192.168.1.20"
                        color: Theme.glassFaint
                        font: field.font
                    }
                }
            }
            Item { width: 1; height: 1.2 * cq }
            Text {
                id: hint
                property bool wrong: false
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: wrong ? qsTr("Enter a name or an address first.")
                            : qsTr("PCs on this network appear by themselves. Use this for one that doesn't.")
                color: wrong ? "#A32D2D" : Theme.glassMuted
                font.family: Theme.sansFont
                font.pixelSize: 1.6 * cq
            }
            Item { width: 1; height: 1.6 * cq }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0.8 * cq
                Rectangle {
                    width: cancelLabel.implicitWidth + 3.8 * cq
                    height: cancelLabel.implicitHeight + 1.5 * cq
                    radius: height / 2
                    color: "#FFFFFF"
                    border.width: 1
                    border.color: Theme.glassPillBorder
                    Text { id: cancelLabel; anchors.centerIn: parent; text: qsTr("Cancel"); color: Theme.glassText; font.family: Theme.sansFont; font.pixelSize: 1.6 * cq }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addView.leave() }
                }
                Rectangle {
                    width: addLabel.implicitWidth + 3.8 * cq
                    height: addLabel.implicitHeight + 1.5 * cq
                    radius: height / 2
                    color: Theme.glassText
                    Text { id: addLabel; anchors.centerIn: parent; text: qsTr("Add"); color: "#FFFFFF"; font.family: Theme.sansFont; font.pixelSize: 1.6 * cq }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addView.add() }
                }
            }
        }
    }
}
