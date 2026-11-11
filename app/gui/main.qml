import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.2
import QtQuick.Controls.Material 2.2

import ComputerManager 1.0
import AutoUpdateChecker 1.0
import InkUpdater 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0
import DeckVoidTheme 1.0

ApplicationWindow {
    // Every control uses the kit font (IBM Plex Sans) unless it sets its own
    font.family: Theme.sansFont
    property bool pollingActive: false

    // Set by SettingsView to force the back operation to pop all
    // pages except the initial view. This is required when doing
    // a retranslate() because AppView breaks for some reason.
    property bool clearOnBack: false

    id: window
    // The glass screens are white; the older screens that are still in use keep their paper
    color: legacyChrome ? Theme.background : "#FFFFFF"
    width: devWindowSize ? devWindowSize.width : 1280
    height: devWindowSize ? devWindowSize.height : 800

    // macOS: draw the app under a transparent title bar, so the close, minimise and
    // maximise buttons sit inside the app instead of in a bar of their own (Qt 6.9+).
    flags: Qt.platform.os === "osx" ? (Qt.Window | (Qt.ExpandedClientAreaHint || 0) | (Qt.NoTitleBarBackgroundHint || 0))
                                    : Qt.Window
    // Room the older screens leave for those buttons
    readonly property int titleInset: Qt.platform.os === "osx" ? 28 : 0
    // Screens not yet moved to the glass design keep the old header and its tabs
    readonly property bool legacyChrome: stackView.currentItem instanceof ClassicSettingsView
    // Set by the home screen: the glass screens turn grey while the PC is off
    property bool pcOff: false

    // This function runs prior to creation of the initial StackView item
    function doEarlyInit() {
        // Override the background color to Material 2 colors for Qt 6.5+
        // in order to improve contrast between GFE's placeholder box art
        // and the background of the app grid.
        Material.theme = Material.Light
        Material.accent = Theme.accent
        Material.background = Theme.background
        Material.foreground = Theme.text
        // Kit: square controls (4 px at most) instead of Material's rounded ones
        Material.roundedScale = Material.ExtraSmallScale

        SdlGamepadKeyNavigation.enable()
    }

    Component.onCompleted: {
        // With the title bar transparent, Qt pads the content down by its height;
        // the glass screens draw under it and leave their own room for the buttons.
        if (window.topPadding !== undefined) {
            window.topPadding = 0
        }

        // Show the window according to the user's preferences
        if (SystemProperties.hasDesktopEnvironment) {
            if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_MAXIMIZED) {
                window.showMaximized()
            }
            else if (StreamingPreferences.uiDisplayMode == StreamingPreferences.UI_FULLSCREEN) {
                window.showFullScreen()
            }
            else {
                window.show()
            }
        } else {
            window.showFullScreen()
        }

        // Display any modal dialogs for configuration warnings
        if (runConfigChecks) {
            if (SystemProperties.isWow64) {
                wow64Dialog.open()
            }

            // Hardware acceleration and unmapped gamepads are checked asynchronously
            SystemProperties.hasHardwareAccelerationChanged.connect(hasHardwareAccelerationChanged)
            SystemProperties.unmappedGamepadsChanged.connect(hasUnmappedGamepadsChanged)
            SystemProperties.startAsyncLoad()
        }
    }

    // Developer aid for screenshots (see main.cpp): open a screen, save the window, quit.
    Timer {
        id: devStartTimer
        interval: 1500
        running: typeof devStartView !== "undefined" && devStartView !== ""
        onTriggered: {
            var parts = devStartView.split(":")
            if (parts[0] === "settings") {
                showSettings()
                if (parts.length > 1) stackView.currentItem.category = parts[1]
            }
            else if (parts[0] === "pair" && stackView.currentItem.openPairPreview) {
                stackView.currentItem.openPairPreview()
            }
            else if (parts[0] === "apps" && stackView.currentItem.openFirstHost) {
                stackView.currentItem.openFirstHost()
            }
            else if (parts[0] === "dialog") {
                devDialog.open()
            }
            else if (parts[0] === "addpc") {
                showAddPc()
            }
            else if (parts[0] === "ready" && stackView.currentItem.devReady !== undefined) {
                stackView.currentItem.devReady = true
            }
        }
    }
    NavigableMessageDialog {
        id: devDialog
        text: qsTr("Are you sure you want to remove '%1'?").arg("Living Room PC")
        standardButtons: Dialog.Yes | Dialog.No
    }

    function hasHardwareAccelerationChanged() {
        if (!SystemProperties.hasHardwareAcceleration && StreamingPreferences.videoDecoderSelection !== StreamingPreferences.VDS_FORCE_SOFTWARE) {
            if (SystemProperties.isRunningXWayland) {
                xWaylandDialog.open()
            }
            else {
                noHwDecoderDialog.open()
            }
        }
    }

    function hasUnmappedGamepadsChanged() {
        if (SystemProperties.unmappedGamepads) {
            unmappedGamepadDialog.unmappedGamepads = SystemProperties.unmappedGamepads
            unmappedGamepadDialog.open()
        }
    }

    // It would be better to use TextMetrics here, but it always lays out
    // the text slightly more compactly than real Text does in ToolTip,
    // causing unexpected line breaks to be inserted
    Text {
        id: tooltipTextLayoutHelper
        visible: false
        font: ToolTip.toolTip.font
        text: ToolTip.toolTip.text
    }

    // This configures the maximum width of the singleton attached QML ToolTip. If left unconstrained,
    // it will never insert a line break and just extend on forever.
    ToolTip.toolTip.contentWidth: Math.min(tooltipTextLayoutHelper.width, 400)

    function goBack() {
        if (clearOnBack) {
            // Pop all items except the first one
            stackView.pop(null)
            clearOnBack = false
        }
        else {
            stackView.pop()
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        focus: true

        Component.onCompleted: {
            // Perform our early initialization before constructing
            // the initial view and pushing it to the StackView
            doEarlyInit()
            push(initialView)
        }

        onCurrentItemChanged: {
            // Ensure focus travels to the next view when going back
            if (currentItem) {
                currentItem.forceActiveFocus()
            }
        }

        Keys.onEscapePressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onBackPressed: {
            if (depth > 1) {
                goBack()
            }
            else {
                quitConfirmationDialog.open()
            }
        }

        Keys.onMenuPressed: {
            showSettings()
        }

        // L1 / R1 switch the Hosts and Settings tabs (sent as F15 / F16).
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_F15) {
                showHosts()
                event.accepted = true
            }
            else if (event.key === Qt.Key_F16) {
                showSettings()
                event.accepted = true
            }
        }

        // This is a keypress we've reserved for letting the
        // SdlGamepadKeyNavigation object tell us to show settings
        // when Menu is consumed by a focused control.
        Keys.onHangupPressed: {
            showSettings()
        }
    }

    // This timer keeps us polling for 5 minutes of inactivity
    // to allow the user to work with Moonlight on a second display
    // while dealing with configuration issues. This will ensure
    // machines come online even if the input focus isn't on Moonlight.
    Timer {
        id: inactivityTimer
        interval: 5 * 60000
        onTriggered: {
            if (!active && pollingActive) {
                ComputerManager.stopPollingAsync()
                pollingActive = false
            }
        }
    }

    onVisibleChanged: {
        // When we become invisible while streaming is going on,
        // stop polling immediately.
        if (!visible) {
            inactivityTimer.stop()

            if (pollingActive) {
                ComputerManager.stopPollingAsync()
                pollingActive = false
            }
        }
        else if (active) {
            // When we become visible and active again, start polling
            inactivityTimer.stop()

            // Restart polling if it was stopped
            if (!pollingActive) {
                ComputerManager.startPolling()
                pollingActive = true
            }
        }

        // Poll for gamepad input only when the window is in focus
        SdlGamepadKeyNavigation.notifyWindowFocus(visible && active)
    }

    onActiveChanged: {
        if (active) {
            // Stop the inactivity timer
            inactivityTimer.stop()

            // Restart polling if it was stopped
            if (!pollingActive) {
                ComputerManager.startPolling()
                pollingActive = true
            }
        }
        else {
            // Start the inactivity timer to stop polling
            // if focus does not return within a few minutes.
            inactivityTimer.restart()
        }

        // Poll for gamepad input only when the window is in focus
        SdlGamepadKeyNavigation.notifyWindowFocus(visible && active)
    }

    function navigateTo(url, objectType)
    {
        var existingItem = stackView.find(function(item, index) {
            return item instanceof objectType
        })

        if (existingItem !== null) {
            // Pop to the existing item
            stackView.pop(existingItem)
        }
        else {
            // Create a new item
            stackView.push(url)
        }
    }

    // Tabs: Hosts is the root of the stack, Settings is pushed on top.
    readonly property bool settingsTab: (stackView.currentItem instanceof SettingsView) || (stackView.currentItem instanceof ClassicSettingsView)
    function showHosts() {
        if (stackView.depth > 1) {
            stackView.pop(null)
        }
    }
    function showSettings() {
        navigateTo("qrc:/gui/SettingsView.qml", SettingsView)
    }
    // The previous settings screen: calibration, custom frame rates and VRR tuning are still only there
    function showClassicSettings() {
        navigateTo("qrc:/gui/ClassicSettingsView.qml", ClassicSettingsView)
    }
    function showAddPc() {
        navigateTo("qrc:/gui/AddPcView.qml", AddPcView)
    }

    // Header: a row of ruled cells (docs/design/KIT.md, "Fact header"):
    // name, the PCs / Settings tabs, and one cell of facts from the current page.
    header: Rectangle {
        id: toolBar
        height: window.legacyChrome ? Theme.headerHeight + window.titleInset : 0
        clip: true
        color: Theme.paper
        readonly property string fact: stackView.currentItem && stackView.currentItem.headerFact !== undefined
                                       ? stackView.currentItem.headerFact : ""

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.ink }

        Row {
            id: cells
            y: window.titleInset
            height: Theme.headerHeight - 1

            Item {
                width: 180; height: parent.height
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "!ink"
                    color: Theme.ink
                    font.family: Theme.sansFont
                    font.weight: Font.Bold
                    font.pixelSize: 20
                    font.letterSpacing: -0.4
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.ink }
            }

            Repeater {
                model: [qsTr("PCs"), qsTr("Settings")]
                delegate: Rectangle {
                    readonly property bool active: index === 1 ? window.settingsTab : !window.settingsTab
                    width: 120; height: cells.height
                    color: active ? Theme.ink : (tabArea.containsMouse ? Theme.ash : "transparent")
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData
                        color: parent.active ? Theme.paper : Theme.ink
                        font.family: Theme.sansFont
                        font.weight: Font.Medium
                        font.pixelSize: 15
                    }
                    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.ink }
                    MouseArea { id: tabArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: index === 1 ? showSettings() : showHosts() }
                }
            }

            Item {
                visible: toolBar.fact !== ""
                width: 260; height: cells.height
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 20
                    anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: toolBar.fact
                    color: "#55514C"
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    lineHeight: 1.15
                    elide: Text.ElideRight
                    maximumLineCount: 2
                }
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.ink }
            }
        }

        // Right: the !ink updater as its own cell (Linux Flatpak only). It shows
        // "Update to <build> ->", then progress, and installs on click or tap.
        Rectangle {
            id: updateButton
            readonly property bool busy: InkUpdater.state === "downloading" || InkUpdater.state === "installing" ||
                                         InkUpdater.state === "restarting"
            visible: InkUpdater.supported && InkUpdater.statusText !== ""
            anchors.right: parent.right
            height: parent.height - 1
            width: updateText.implicitWidth + 40
            color: InkUpdater.state === "error" ? Theme.accentTint
                 : (updateArea.containsMouse && !busy ? Theme.ash : "transparent")
            Rectangle { anchors.left: parent.left; width: 1; height: parent.height; color: Theme.ink }
            Text {
                id: updateText
                anchors.centerIn: parent
                text: InkUpdater.statusText
                color: Theme.ink
                font.family: updateButton.busy ? Theme.monoFont : Theme.sansFont
                font.weight: Font.Medium
                font.pixelSize: updateButton.busy ? 13 : 14
            }
            MouseArea {
                id: updateArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !updateButton.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: InkUpdater.update()
            }
        }

        Shortcut { sequence: StandardKey.New; onActivated: showAddPc() }
        Shortcut { sequence: StandardKey.Preferences; onActivated: showSettings() }
        Shortcut { sequence: StandardKey.HelpContents; onActivated: Qt.openUrlExternally("https://github.com/oaa20203-source/deckvoid#readme") }
    }

    // Footer (controller mode): what is selected on the left, button hints in mono
    // on the right. Pages provide footerHints ([glyph, label] pairs) and footerStatus.
    footer: Rectangle {
        id: hintBar
        readonly property var hints: stackView.currentItem && stackView.currentItem.footerHints !== undefined
                                     ? stackView.currentItem.footerHints : []
        readonly property string status: stackView.currentItem && stackView.currentItem.footerStatus !== undefined
                                         ? stackView.currentItem.footerStatus : ""
        visible: Theme.controllerMode && hints.length > 0
        height: visible ? Theme.footerHeight : 0
        color: Theme.paper
        Rectangle { width: parent.width; height: 1; color: Theme.ink }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 32
            anchors.verticalCenter: parent.verticalCenter
            text: hintBar.status
            color: "#55514C"
            font.family: Theme.monoFont
            font.pixelSize: 13
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 32
            anchors.verticalCenter: parent.verticalCenter
            spacing: 28
            Repeater {
                model: hintBar.hints
                delegate: Row {
                    spacing: 7
                    Text { text: modelData[0]; color: Theme.ink; font.family: Theme.monoFont; font.weight: Font.Medium; font.pixelSize: 13 }
                    Text { text: modelData[1].toLowerCase(); color: "#55514C"; font.family: Theme.monoFont; font.pixelSize: 13 }
                }
            }
        }
    }

    ErrorMessageDialog {
        id: noHwDecoderDialog
        text: qsTr("No functioning hardware accelerated video decoder was detected by Moonlight. " +
                   "Your streaming performance may be severely degraded in this configuration.")
        helpText: qsTr("Click the Help button for more information on solving this problem.")
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Fixing-Hardware-Decoding-Problems"
    }

    ErrorMessageDialog {
        id: xWaylandDialog
        text: qsTr("Hardware acceleration doesn't work on XWayland. Continuing on XWayland may result in poor streaming performance. " +
                   "Try running with QT_QPA_PLATFORM=wayland or switch to X11.")
        helpText: qsTr("Click the Help button for more information.")
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Fixing-Hardware-Decoding-Problems"
    }

    NavigableMessageDialog {
        id: wow64Dialog
        standardButtons: Dialog.Ok | Dialog.Cancel
        text: qsTr("This version of Moonlight isn't optimized for your PC. Please download the '%1' version of Moonlight for the best streaming performance.").arg(SystemProperties.friendlyNativeArchName)
        onAccepted: {
            Qt.openUrlExternally("https://github.com/Nonary/moonlight-qt/releases");
        }
    }

    ErrorMessageDialog {
        id: unmappedGamepadDialog
        property string unmappedGamepads : ""
        text: qsTr("Moonlight detected gamepads without a mapping:") + "\n" + unmappedGamepads
        helpTextSeparator: "\n\n"
        helpText: qsTr("Click the Help button for information on how to map your gamepads.")
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Gamepad-Mapping"
    }

    // This dialog appears when quitting via keyboard or gamepad button
    NavigableMessageDialog {
        id: quitConfirmationDialog
        standardButtons: Dialog.Yes | Dialog.No
        text: qsTr("Are you sure you want to quit?")
        // For keyboard/gamepad navigation
        onAccepted: Qt.quit()
    }

    // HACK: This belongs in StreamSegue but keeping a dialog around after the parent
    // dies can trigger bugs in Qt 5.12 that cause the app to crash. For now, we will
    // host this dialog in a QML component that is never destroyed.
    //
    // To repro: Start a stream, cut the network connection to trigger the "Connection
    // terminated" dialog, wait until the app grid times out back to the PC grid, then
    // try to dismiss the dialog.
    ErrorMessageDialog {
        id: streamSegueErrorDialog

        property bool quitAfter: false

        onClosed: {
            if (quitAfter) {
                Qt.quit()
            }

            // StreamSegue assumes its dialog will be re-created each time we
            // start streaming, so fake it by wiping out the text each time.
            text = ""
        }
    }

    NavigableDialog {
        id: addPcDialog
        property string label: qsTr("Enter the IP address of your host PC:")

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
                ComputerManager.addNewHostManually(editText.text.trim())
            }
        }

        ColumnLayout {
            Label {
                text: addPcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    addPcDialog.accept()
                }

                Keys.onEnterPressed: {
                    addPcDialog.accept()
                }
            }
        }
    }
}
