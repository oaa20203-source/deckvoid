import QtQuick 2.0
import QtQuick.Controls 2.5
import DeckVoidTheme 1.0

// Base for every DeckVoid dialog: light, rounded, over a warm scrim.
Dialog {
    id: navDialog
    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 28

    Overlay.modal: Rectangle { color: Theme.scrim }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusDialog
        border.color: Theme.line
        border.width: 1
    }

    header: Text {
        visible: navDialog.title !== ""
        text: navDialog.title
        leftPadding: 28; rightPadding: 28; topPadding: visible ? 26 : 0
        color: Theme.text
        font.family: Theme.headingFont
        font.weight: Font.Bold
        font.pixelSize: Theme.px(26)
        elide: Text.ElideRight
    }

    footer: DialogButtonBox {
        standardButtons: navDialog.standardButtons
        visible: count > 0
        padding: 20
        spacing: 12
        background: Item {}

        delegate: Button {
            id: dvDialogButton
            flat: true
            // The last button (OK / Yes / Pair) is the filled one.
            readonly property bool primaryButton: DialogButtonBox.buttonRole === DialogButtonBox.AcceptRole ||
                                                  DialogButtonBox.buttonRole === DialogButtonBox.YesRole
            implicitHeight: Theme.mouseMode ? 36 : 48
            leftPadding: 22; rightPadding: 22
            background: Rectangle {
                radius: height / 2
                color: dvDialogButton.primaryButton ? (dvDialogButton.down ? Qt.darker(Theme.accent, 1.06) : Theme.accent) : Theme.chip
                border.width: dvDialogButton.activeFocus ? 2.5 : 0
                border.color: dvDialogButton.primaryButton ? Theme.accentDeep : Theme.accent
            }
            contentItem: Text {
                text: dvDialogButton.text
                color: Theme.text
                font.family: Theme.bodyFont
                font.weight: Font.Bold
                font.pixelSize: Theme.px(17)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
            Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
            Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
        }
    }

    onClosed: {
        // We must force focus back to the last item. If we don't,
        // gamepad and keyboard navigation will break after a
        // dialog appears.
        stackView.forceActiveFocus()
    }
}
