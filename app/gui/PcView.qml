import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import ComputerModel 1.0

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0
import DeckVoidTheme 1.0

// Hosts screen (docs/design/DESIGN.md, mockups/*-hosts): a card per PC, an
// "Add a PC" card, and a details strip for the selected PC.
FocusScope {
    id: pcView
    property ComputerModel computerModel : createModel()
    objectName: qsTr("Computers")
    focus: true
    activeFocusOnTab: true

    // Selected card: 0..count-1 are PCs, count is the "Add a PC" card. -1 until used.
    property int currentIndex: -1
    readonly property int count: hostRepeater.count
    readonly property int columns: 4
    readonly property var selectedCard: currentIndex >= 0 && currentIndex < count ? hostRepeater.itemAt(currentIndex) : null

    // Controller footer hints for the selected card (read by main.qml).
    readonly property var footerHints: {
        var hints = []
        var c = selectedCard
        if (currentIndex === count) {
            hints.push(["A", qsTr("Add a PC")])
        }
        else if (c) {
            if (c.card.status === "ready") hints.push(["A", qsTr("Open apps")])
            if (c.card.status === "pairing") {
                hints.push(["A", qsTr("Pair")])
                if (c.apolloHost) hints.push(["X", qsTr("Pair with PIN")])
            }
            if (c.card.status === "asleep" && c.card.wakeable) hints.push(["Y", qsTr("Wake")])
            hints.push(["≡", qsTr("Options")])
        }
        hints.push(["B", qsTr("Quit")])
        return hints
    }

    Component.onCompleted: {
        // Don't show any highlighted item until interacting with them.
        currentIndex = -1
    }

    // Note: Any initialization done here that is critical for streaming must
    // also be done in CliStartStreamSegue.qml, since this code does not run
    // for command-line initiated streams.
    StackView.onActivated: {
        // Setup signals on CM
        ComputerManager.computerAddCompleted.connect(addComplete)

        // Highlight the first item if a gamepad is connected
        if (currentIndex === -1 && (SdlGamepadKeyNavigation.getConnectedGamepads() > 0 || Theme.controllerMode)) {
            currentIndex = 0
        }
    }

    StackView.onDeactivating: {
        ComputerManager.computerAddCompleted.disconnect(addComplete)
    }

    function pairingComplete(error)
    {
        // Close the PIN dialog
        pairDialog.close()

        // Display a failed dialog if we got an error
        if (error !== undefined) {
            errorDialog.text = error
            errorDialog.helpText = ""
            errorDialog.open()
        }
    }

    function addComplete(success, detectedPortBlocking)
    {
        if (!success) {
            errorDialog.text = qsTr("Unable to connect to the specified PC.")

            if (detectedPortBlocking) {
                errorDialog.text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
            }
            else {
                errorDialog.helpText = qsTr("Click the Help button for possible solutions.")
            }

            errorDialog.open()
        }
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(testConnectionDialog.connectionTestComplete)
        return model
    }


    function select(index) {
        currentIndex = Math.max(0, Math.min(index, count))
        var item = currentIndex < count ? hostRepeater.itemAt(currentIndex) : addCard
        if (item) flick.ensureVisible(item)
    }

    function activateComputer(index, model) {
            if (model.online) {
                if (!model.serverSupported) {
                    errorDialog.text = qsTr("The version of GeForce Experience on %1 is not supported by this build of Moonlight. You must update Moonlight to stream from %1.").arg(model.name)
                    errorDialog.helpText = ""
                    errorDialog.open()
                }
                else if (model.paired) {
                    // go to game view
                    var component = Qt.createComponent("AppView.qml")
                    var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name})
                    stackView.push(appView)
                }
                else {
                    var pin = computerModel.generatePinString()

                    // Kick off pairing in the background
                    computerModel.pairComputer(index, pin)

                    // Display the pairing dialog
                    pairDialog.otp = false
                    pairDialog.pin = pin
                    pairDialog.open()
                }
            } else if (!model.online) {
                // Using open() here because it may be activated by keyboard
                openMenu(index)
            }
            }

    function openMenu(index) {
        var item = hostRepeater.itemAt(index)
        if (item) item.openMenu(!Theme.mouseMode)
    }

    Keys.onLeftPressed: select(currentIndex < 0 ? 0 : currentIndex - 1)
    Keys.onRightPressed: select(currentIndex < 0 ? 0 : currentIndex + 1)
    Keys.onUpPressed: function(event) {
        if (currentIndex >= columns) select(currentIndex - columns)
        else event.accepted = false // let the header take focus
    }
    Keys.onDownPressed: select(currentIndex < 0 ? 0 : Math.min(currentIndex + columns, count))
    Keys.onReturnPressed: activateSelected()
    Keys.onEnterPressed: activateSelected()
    Keys.onSpacePressed: activateSelected()
    Keys.onMenuPressed: function(event) {
        if (currentIndex >= 0 && currentIndex < count) openMenu(currentIndex)
        else event.accepted = false
    }
    Keys.onDeletePressed: {
        var item = selectedCard
        if (item) {
            deletePcDialog.pcIndex = currentIndex
            deletePcDialog.pcName = item.card.name
            deletePcDialog.open()
        }
    }
    Keys.onPressed: function(event) {
        var item = selectedCard
        if (event.key === Qt.Key_F13 && item) {          // X: pair with PIN
            item.pair()
            event.accepted = true
        }
        else if (event.key === Qt.Key_F14 && item) {     // Y: wake
            if (!item.card.online && item.card.wakeable) computerModel.wakeComputer(currentIndex)
            event.accepted = true
        }
    }

    function activateSelected() {
        if (currentIndex === count) addPcDialog.open()
        else if (selectedCard) selectedCard.activate()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        function ensureVisible(item) {
            var p = item.mapToItem(content, 0, 0)
            if (p.y - 24 < contentY) contentY = Math.max(0, p.y - 24)
            else if (p.y + item.height + 24 > contentY + height) contentY = Math.min(contentHeight - height, p.y + item.height + 24 - height)
        }

        Column {
            id: content
            x: Theme.pageGutter
            y: Theme.controllerMode ? 34 : 28
            width: flick.width - 2 * Theme.pageGutter
            spacing: 24

            Item {
                width: parent.width
                height: titleText.height
                Text {
                    id: titleText
                    text: qsTr("Your PCs")
                    color: Theme.text
                    font.family: Theme.headingFont
                    font.weight: Font.ExtraBold
                    font.pixelSize: Theme.pageTitle
                }
                Text {
                    anchors.right: parent.right
                    anchors.baseline: titleText.baseline
                    color: Theme.textMuted
                    font.family: Theme.bodyFont
                    font.weight: Font.Medium
                    font.pixelSize: Theme.body
                    text: {
                        var online = 0
                        for (var i = 0; i < hostRepeater.count; i++) {
                            var it = hostRepeater.itemAt(i)
                            if (it && it.card.online) online++
                        }
                        return (hostRepeater.count === 1 ? qsTr("1 PC") : qsTr("%1 PCs").arg(hostRepeater.count)) +
                               " · " + qsTr("%1 online on this network").arg(online)
                    }
                }
            }

            Row {
                spacing: 12
                visible: hostRepeater.count === 0
                BusyIndicator {
                    id: searchSpinner
                    visible: StreamingPreferences.enableMdns
                    running: visible
                    width: 32; height: 32
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: StreamingPreferences.enableMdns ? qsTr("Searching for compatible hosts on your local network...")
                                                          : qsTr("Automatic PC discovery is disabled. Add your PC manually.")
                    color: Theme.textSecondary
                    font.family: Theme.bodyFont
                    font.pixelSize: Theme.body
                }
            }

            Grid {
                id: grid
                width: parent.width
                columns: pcView.columns
                columnSpacing: Theme.gridGap
                rowSpacing: Theme.gridGap + 8
                readonly property real cardWidth: (width - (columns - 1) * columnSpacing) / columns
                readonly property real cardHeight: Math.round(cardWidth * 0.96)

                Repeater {
                    id: hostRepeater
                    model: computerModel

                    delegate: Item {
                        id: hostItem
                        width: grid.cardWidth
                        height: grid.cardHeight
                        property alias card: hostCard
                        readonly property bool apolloHost: model.hostKind === "Apollo"
                        readonly property string address: model.address
                        readonly property string virtualDisplay: model.virtualDisplay
                        readonly property string permissions: model.permissionsSummary
                        property alias pcContextMenu: pcContextMenuLoader.item

                        function activate() { pcView.activateComputer(index, model) }
                        function pair() {
                            if (!model.online || model.paired) return
                            if (apolloHost) {
                                otpPairDialog.pcIndex = index
                                otpPairDialog.open()
                            }
                            else {
                                pcView.activateComputer(index, model)
                            }
                        }
                        function openMenu(keyboard) {
                            if (!pcContextMenu) return
                            if (keyboard || !pcContextMenu.popup) pcContextMenu.open()
                            else pcContextMenu.popup()
                        }

                        HostCard {
                            id: hostCard
                            anchors.fill: parent
                            name: model.name
                            online: model.online
                            paired: model.paired
                            statusUnknown: model.statusUnknown
                            wakeable: model.wakeable
                            hostKind: model.hostKind
                            runningApp: model.runningApp
                            selected: pcView.currentIndex === index && pcView.activeFocus
                            onSelectRequested: pcView.currentIndex = index
                            onActivated: hostItem.activate()
                            onPairRequested: hostItem.pair()
                            onWakeRequested: computerModel.wakeComputer(index)
                            onMenuRequested: hostItem.openMenu(false)
                        }

                        Loader {
                            id: pcContextMenuLoader
                            asynchronous: true
                            sourceComponent: NavigableMenu {
                                id: pcContextMenu
                                initiator: hostItem
                MenuItem {
                    text: qsTr("PC Status: %1").arg(model.online ? qsTr("Online") : qsTr("Offline"))
                    font.bold: true
                    enabled: false
                }
                NavigableMenuItem {
                    text: qsTr("View All Apps")
                    onTriggered: {
                        var component = Qt.createComponent("AppView.qml")
                        var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name, "showHiddenGames": true})
                        stackView.push(appView)
                    }
                    visible: model.online && model.paired
                }
                NavigableMenuItem {
                    text: qsTr("Wake PC")
                    onTriggered: computerModel.wakeComputer(index)
                    visible: !model.online && model.wakeable
                }
                NavigableMenuItem {
                    text: qsTr("Test Network")
                    onTriggered: {
                        computerModel.testConnectionForComputer(index)
                        testConnectionDialog.open()
                    }
                }

                NavigableMenuItem {
                    text: qsTr("Pair with PIN and Passphrase...")
                    visible: model.online && !model.paired && computerModel.isApolloHost(index)
                    height: visible ? implicitHeight : 0
                    onTriggered: {
                        otpPairDialog.pcIndex = index
                        otpPairDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("Rename PC")
                    onTriggered: {
                        renamePcDialog.pcIndex = index
                        renamePcDialog.originalName = model.name
                        renamePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("Delete PC")
                    onTriggered: {
                        deletePcDialog.pcIndex = index
                        deletePcDialog.pcName = model.name
                        deletePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("View Details")
                    onTriggered: {
                        showPcDetailsDialog.pcDetails = model.details
                        showPcDetailsDialog.open()
                    }
                }
                            }
                        }
                    }
                }

                AddPcCard {
                    id: addCard
                    width: grid.cardWidth
                    height: grid.cardHeight
                    selected: pcView.currentIndex === hostRepeater.count && pcView.activeFocus
                    onSelectRequested: pcView.currentIndex = hostRepeater.count
                    onActivated: addPcDialog.open()
                }
            }

            // Details strip for the selected (or first) PC
            Rectangle {
                id: details
                readonly property var item: pcView.selectedCard ? pcView.selectedCard
                                          : (hostRepeater.count > 0 ? hostRepeater.itemAt(0) : null)
                readonly property var info: item
                visible: item !== null && item.card.online
                width: parent.width
                height: detailsRow.height + 48
                radius: Theme.radiusCard
                color: Theme.surface
                border.color: Theme.line
                border.width: 1

                Row {
                    id: detailsRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 36
                    anchors.rightMargin: 24
                    spacing: 16
                    readonly property var entries: {
                        var e = []
                        var info = details.info
                        if (!info) return e
                        e.push([qsTr("ADDRESS"), info.address])
                        if (info.virtualDisplay !== "") e.push([qsTr("VIRTUAL DISPLAY"), info.virtualDisplay])
                        if (info.permissions !== "") e.push([qsTr("ALLOWED ON THIS DEVICE"), info.permissions])
                        e.push([qsTr("HOST"), info.card.hostKind + (info.card.runningApp !== "" ? " · " + info.card.runningApp : "")])
                        return e
                    }

                    Repeater {
                        model: detailsRow.entries
                        delegate: Column {
                            width: (detailsRow.width - (detailsRow.entries.length - 1) * detailsRow.spacing) / detailsRow.entries.length
                            spacing: 8
                            Row {
                                spacing: 10
                                Rectangle { width: 9; height: 9; radius: 2; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: modelData[0]
                                    color: Theme.textSecondary
                                    font.family: Theme.bodyFont
                                    font.weight: Font.Bold
                                    font.pixelSize: Theme.label
                                    font.letterSpacing: Theme.label * Theme.labelTracking / 10
                                }
                            }
                            Text {
                                width: parent.width
                                text: modelData[1]
                                color: Theme.text
                                font.family: Theme.bodyFont
                                font.weight: Font.Medium
                                font.pixelSize: Theme.row
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }

    ErrorMessageDialog {
        id: errorDialog

        // Using Setup-Guide here instead of Troubleshooting because it's likely that users
        // will arrive here by forgetting to enable GameStream or not forwarding ports.
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    NavigableMessageDialog {
        id: pairDialog
        closePolicy: Popup.CloseOnEscape

        // don't allow edits to the rest of the window while open
        property string pin : "0000"
        property bool otp: false
        text: otp ? qsTr("Pairing with the one-time PIN... This dialog will close when pairing is completed.")
                  : qsTr("Please enter %1 on your host PC. This dialog will close when pairing is completed.").arg(pin)+"\n\n"+
                    qsTr("If your host PC is running Apollo, Vibepollo or Sunshine, enter the PIN in the host's web UI.")
        standardButtons: Dialog.Cancel
        onRejected: {
            // FIXME: We should interrupt pairing here
        }
    }

    NavigableMessageDialog {
        id: deletePcDialog
        // don't allow edits to the rest of the window while open
        property int pcIndex : -1
        property string pcName : ""
        text: qsTr("Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            computerModel.deleteComputer(pcIndex)
        }
    }

    NavigableMessageDialog {
        id: testConnectionDialog
        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            testConnectionDialog.text = qsTr("Moonlight is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTr("This may take a few seconds…")
            showSpinner = true
        }

        function connectionTestComplete(result, blockedPorts)
        {
            if (result === -1) {
                text = qsTr("The network test could not be performed because none of Moonlight's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                imageSrc = "qrc:/res/baseline-warning-24px.svg"
            }
            else if (result === 0) {
                text = qsTr("This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTr("If you are trying to stream over the Internet, install the Moonlight Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                imageSrc = "qrc:/res/baseline-check_circle_outline-24px.svg"
            }
            else {
                text = qsTr("Your PC's current network connection seems to be blocking Moonlight. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTr("The following network ports were blocked:") + "\n"
                text += blockedPorts
                imageSrc = "qrc:/res/baseline-error_outline-24px.svg"
            }

            // Stop showing the spinner and show the image instead
            showSpinner = false
        }
    }

    NavigableDialog {
        id: otpPairDialog
        property int pcIndex: -1

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: otpPinField.forceActiveFocus()
        onClosed: {
            otpPinField.clear()
            otpPassphraseField.clear()
        }

        onAccepted: {
            if (!computerModel.isValidOtp(otpPinField.text, otpPassphraseField.text)) {
                errorDialog.text = qsTr("Enter the 4-digit PIN and a passphrase of at least 4 characters.")
                errorDialog.helpText = ""
                errorDialog.open()
                return
            }
            computerModel.pairComputerWithOtp(pcIndex, otpPinField.text, otpPassphraseField.text)
            pairDialog.otp = true
            pairDialog.open()
        }

        ColumnLayout {
            Label {
                text: qsTr("Pair with a one-time PIN")
                font.bold: true
            }

            Label {
                Layout.maximumWidth: 420
                wrapMode: Text.Wrap
                text: qsTr("Create a one-time PIN and passphrase on the host (Apollo: web UI, PIN page). Enter them here within 3 minutes. Nothing needs to be typed on the host afterwards.")
            }

            TextField {
                id: otpPinField
                Layout.fillWidth: true
                placeholderText: qsTr("4-digit PIN")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 9999 }
                maximumLength: 4
                KeyNavigation.down: otpPassphraseField
            }

            TextField {
                id: otpPassphraseField
                Layout.fillWidth: true
                placeholderText: qsTr("Passphrase")
                echoMode: TextInput.Password
                Keys.onReturnPressed: otpPairDialog.accept()
                Keys.onEnterPressed: otpPairDialog.accept()
            }
        }
    }

    NavigableDialog {
        id: renamePcDialog
        property string label: qsTr("Enter the new name for this PC:")
        property string originalName
        property int pcIndex : -1;

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                computerModel.renameComputer(pcIndex, editText.text)
            }
        }

        ColumnLayout {
            Label {
                text: renamePcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                placeholderText: renamePcDialog.originalName
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    renamePcDialog.accept()
                }

                Keys.onEnterPressed: {
                    renamePcDialog.accept()
                }
            }
        }
    }

    NavigableMessageDialog {
        id: showPcDetailsDialog
        property string pcDetails : "";
        text: showPcDetailsDialog.pcDetails
        imageSrc: "qrc:/res/baseline-help_outline-24px.svg"
        standardButtons: Dialog.Ok
    }

}
