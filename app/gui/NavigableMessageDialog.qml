import QtQuick 2.0
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.2
import DeckVoidTheme 1.0

NavigableDialog {
    id: dialog

    property alias text: dialogLabel.dialogText
    property alias showSpinner: dialogSpinner.visible
    property alias imageSrc: dialogImage.source

    property string helpText
    property string helpUrl : "https://github.com/moonlight-stream/moonlight-docs/wiki/Troubleshooting"
    property string helpTextSeparator : " "

    onOpened: {
        // Force keyboard focus on the label so keyboard navigation works
        if (dialogButtonBox.count > 0) {
            dialogButtonBox.itemAt(dialogButtonBox.count - 1).forceActiveFocus(Qt.TabFocus)
        }
    }

    RowLayout {
        spacing: 10

        BusyIndicator {
            id: dialogSpinner
            visible: false
            running: visible
        }

        Image {
            id: dialogImage
            source: (standardButtons & Dialog.Yes) ?
                        "qrc:/res/baseline-help_outline-24px.svg" :
                        "qrc:/res/baseline-error_outline-24px.svg"
            sourceSize {
                // The icon should be square so use the height as the width too
                width: 50
                height: 50
            }
            visible: !showSpinner
        }

        Label {
            property string dialogText

            id: dialogLabel
            text: dialogText + ((helpText && (standardButtons & Dialog.Help)) ? (helpTextSeparator + helpText) : "")
            wrapMode: Text.Wrap
            elide: Label.ElideRight
            color: Theme.text
            font.family: Theme.bodyFont
            font.pixelSize: Theme.body
            lineHeight: 1.15

            // Cap the width so the dialog doesn't grow horizontally forever. This
            // will cause word wrap to kick in.
            Layout.maximumWidth: 400
            Layout.maximumHeight: 400
        }
    }

    footer: DialogButtonBox {
        id: dialogButtonBox
        standardButtons: dialog.standardButtons
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

        onHelpRequested: {
            Qt.openUrlExternally(helpUrl)
            close()
        }
    }
}
