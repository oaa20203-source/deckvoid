import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.2
import QtQuick.Controls.Material 2.2

import ComputerManager 1.0
import AutoUpdateChecker 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0
import DeckVoidTheme 1.0

ApplicationWindow {
    property bool pollingActive: false

    // Set by SettingsView to force the back operation to pop all
    // pages except the initial view. This is required when doing
    // a retranslate() because AppView breaks for some reason.
    property bool clearOnBack: false

    id: window
    color: Theme.background
    width: devWindowSize ? devWindowSize.width : 1280
    height: devWindowSize ? devWindowSize.height : 600

    // This function runs prior to creation of the initial StackView item
    function doEarlyInit() {
        // Override the background color to Material 2 colors for Qt 6.5+
        // in order to improve contrast between GFE's placeholder box art
        // and the background of the app grid.
        Material.theme = Material.Light
        Material.accent = Theme.accent
        Material.background = Theme.background
        Material.foreground = Theme.text

        SdlGamepadKeyNavigation.enable()
    }

    Component.onCompleted: {
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
    readonly property bool settingsTab: stackView.currentItem instanceof SettingsView
    function showHosts() {
        if (stackView.depth > 1) {
            stackView.pop(null)
        }
    }
    function showSettings() {
        navigateTo("qrc:/gui/SettingsView.qml", SettingsView)
    }

    header: Rectangle {
        id: toolBar
        height: Theme.mouseMode ? 64 : 76
        color: Theme.mouseMode ? Theme.surfaceMuted : Theme.background

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.line }

        // Left: back (inside a host's apps) and the DeckVoid logo
        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.pageGutter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Rectangle {
                id: backButton
                visible: stackView.depth > 1 && !window.settingsTab
                width: 40; height: 40; radius: 20
                color: backArea.containsMouse ? Theme.chip : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: "‹"; color: Theme.text; font.pixelSize: 30; font.weight: Font.Bold; anchors.verticalCenterOffset: -2 }
                MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: goBack() }
            }

            // Logo: mango ring with an orchid dot
            Rectangle {
                width: 34; height: 34; radius: 17
                color: "transparent"
                border.color: Theme.accent; border.width: 4
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.centerIn: parent; width: 13; height: 13; radius: 7; color: Theme.secondary }
            }
            Text {
                text: "DeckVoid"
                color: Theme.text
                font.family: Theme.headingFont
                font.weight: Font.ExtraBold
                font.pixelSize: Theme.mouseMode ? 24 : 28
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Centre: Hosts / Settings
        Row {
            id: controllerTabs
            visible: Theme.controllerMode
            anchors.centerIn: parent
            spacing: 18
            DvGlyph { glyph: "L1"; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: [qsTr("Hosts"), qsTr("Settings")]
                delegate: Item {
                    readonly property bool active: index === 1 ? window.settingsTab : !window.settingsTab
                    width: tabText.implicitWidth + 36
                    height: toolBar.height
                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.active ? Theme.text : Theme.textMuted
                        font.family: Theme.bodyFont
                        font.weight: parent.active ? Font.Bold : Font.DemiBold
                        font.pixelSize: Theme.tab
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width; height: 3; radius: 1.5
                        color: Theme.secondary
                        visible: parent.active
                    }
                    MouseArea { anchors.fill: parent; onClicked: index === 1 ? showSettings() : showHosts() }
                }
            }
            DvGlyph { glyph: "R1"; anchors.verticalCenter: parent.verticalCenter }
        }

        Rectangle {
            id: segmentedTabs
            visible: !Theme.controllerMode
            anchors.centerIn: parent
            width: segRow.width + 8; height: Theme.mouseMode ? 40 : 52
            radius: Theme.mouseMode ? 10 : 18
            color: Theme.chip
            Row {
                id: segRow
                anchors.centerIn: parent
                Repeater {
                    model: [qsTr("Hosts"), qsTr("Settings")]
                    delegate: Rectangle {
                        readonly property bool active: index === 1 ? window.settingsTab : !window.settingsTab
                        width: segText.implicitWidth + (Theme.mouseMode ? 52 : 76)
                        height: segmentedTabs.height - 8
                        radius: segmentedTabs.radius - 3
                        color: active ? Theme.surface : "transparent"
                        Text {
                            id: segText
                            anchors.centerIn: parent
                            text: modelData
                            color: parent.active ? Theme.text : Theme.textMuted
                            font.family: Theme.bodyFont
                            font.weight: Font.Bold
                            font.pixelSize: Theme.tab
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: index === 1 ? showSettings() : showHosts() }
                    }
                }
            }
        }

        // Right: update notice, help, add PC
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.pageGutter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Rectangle {
                id: updateButton
                property string browserUrl: ""
                property string updateVersion: ""
                visible: false
                height: 34; width: updateText.implicitWidth + 28; radius: 17
                color: Theme.accentTint
                border.color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                Text { id: updateText; anchors.centerIn: parent; text: qsTr("Update available"); color: Theme.text; font.family: Theme.bodyFont; font.weight: Font.Bold; font.pixelSize: 14 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            AutoUpdateChecker.dismissUpdate(updateButton.updateVersion)
                            updateButton.visible = false
                        }
                        else if (SystemProperties.hasBrowser) {
                            Qt.openUrlExternally(updateButton.browserUrl)
                            AutoUpdateChecker.dismissUpdate(updateButton.updateVersion)
                            updateButton.visible = false
                        }
                    }
                }
                ToolTip.visible: updateHover.hovered
                ToolTip.text: qsTr("Update available for DeckVoid: Version %1").arg(updateVersion)
                HoverHandler { id: updateHover }

                function updateAvailable(version, url) {
                    updateButton.browserUrl = url
                    updateButton.updateVersion = version
                    updateButton.visible = true
                }
                Connections {
                    target: AutoUpdateChecker
                    function onNotifyPrereleasesChanged() {
                        updateButton.visible = false
                        AutoUpdateChecker.start()
                    }
                }
                Component.onCompleted: {
                    AutoUpdateChecker.onUpdateAvailable.connect(updateAvailable)
                    AutoUpdateChecker.start()
                }
            }

            Rectangle {
                id: helpButton
                visible: Theme.mouseMode && SystemProperties.hasBrowser
                width: 36; height: 36; radius: 18
                color: helpArea.containsMouse ? Theme.chip : "transparent"
                border.color: Theme.lineStrong; border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: "?"; color: Theme.textSecondary; font.family: Theme.bodyFont; font.weight: Font.Bold; font.pixelSize: 17 }
                MouseArea { id: helpArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: helpButton.open() }
                function open() { Qt.openUrlExternally("https://github.com/oaa20203-source/deckvoid#readme") }
                Shortcut { sequence: StandardKey.HelpContents; onActivated: helpButton.open() }
            }

            DvButton {
                id: addPcButton
                visible: Theme.mouseMode && stackView.currentItem instanceof PcView
                text: qsTr("+  Add PC")
                anchors.verticalCenter: parent.verticalCenter
                onClicked: addPcDialog.open()
            }

            Rectangle {
                visible: Theme.touchMode && stackView.currentItem instanceof PcView
                width: 56; height: 56; radius: 28
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                Item {
                    anchors.centerIn: parent; width: 24; height: 24
                    Rectangle { anchors.centerIn: parent; width: 24; height: 3.5; radius: 2; color: Theme.text }
                    Rectangle { anchors.centerIn: parent; width: 3.5; height: 24; radius: 2; color: Theme.text }
                }
                MouseArea { anchors.fill: parent; onClicked: addPcDialog.open() }
            }
        }

        Shortcut { sequence: StandardKey.New; onActivated: addPcDialog.open() }
        Shortcut { sequence: StandardKey.Preferences; onActivated: showSettings() }
    }

    // Controller button hints (controller mode only). Pages provide footerHints:
    // a list of [glyph, label] pairs for the focused item.
    footer: Rectangle {
        readonly property var hints: stackView.currentItem && stackView.currentItem.footerHints !== undefined
                                     ? stackView.currentItem.footerHints : []
        visible: Theme.controllerMode && hints.length > 0
        height: visible ? 66 : 0
        color: Theme.surfaceMuted
        Rectangle { width: parent.width; height: 1; color: Theme.line }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.pageGutter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 34
            Repeater {
                model: parent.parent.hints
                delegate: Row {
                    spacing: 12
                    DvGlyph { glyph: modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: modelData[1]
                        color: Theme.text
                        font.family: Theme.bodyFont
                        font.weight: Font.DemiBold
                        font.pixelSize: Theme.row
                        anchors.verticalCenter: parent.verticalCenter
                    }
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
