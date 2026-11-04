import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

import StreamingPreferences 1.0
import AppModel 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0
import DeckVoidTheme 1.0

CenteredGridView {
    property int computerIndex
    property AppModel appModel : createModel()
    property bool activated
    property bool showHiddenGames
    property bool showGames
    property bool sleepPending: false
    Connections {
        target: appModel
        function onHostSleepCompleted(error) {
            appGrid.sleepPending = false
            sleepResult.imageSrc = error.length ? "qrc:/res/baseline-error_outline-24px.svg" : "qrc:/res/baseline-check_circle_outline-24px.svg"
            sleepResult.text = error.length ? error : qsTr("The host accepted the sleep request. Sleep completion depends on the host. No stream was started.")
            sleepResult.open()
        }
    }

    id: appGrid
    focus: true
    activeFocusOnTab: true
    topMargin: 28
    minMargin: Theme.pageGutter
    bottomMargin: 5
    cellWidth: 260; cellHeight: 440;

    // Header fact cell, footer status and hints (read by main.qml).
    readonly property string headerFact: objectName + "\n" + (count === 1 ? qsTr("1 app") : qsTr("%1 apps").arg(count))
    readonly property string footerStatus: currentItem ? qsTr("%1 selected").arg(currentItem.appName) : ""
    readonly property var footerHints: [["A", currentItem && currentItem.appRunning ? qsTr("Resume") : qsTr("Launch")],
                                        ["B", qsTr("Back")], ["≡", qsTr("Options")]]

    // Title row: back link and the page title (docs/design/KIT.md)
    header: Item {
        width: appGrid.width - appGrid.leftMargin - appGrid.rightMargin
        height: 92
        Row {
            y: 4
            spacing: 24
            Text {
                anchors.baseline: pageTitle.baseline
                text: qsTr("← PCs")
                color: Theme.ink
                font.family: Theme.sansFont
                font.weight: Font.Medium
                font.pixelSize: 15
                font.underline: true
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: stackView.pop() }
            }
            Text {
                id: pageTitle
                text: qsTr("Apps on %1").arg(appGrid.objectName)
                color: Theme.ink
                font.family: Theme.sansFont
                font.weight: Font.Bold
                font.pixelSize: 40
                font.letterSpacing: -1.2
            }
        }
    }

    function computerLost()
    {
        // Go back to the PC view on PC loss
        stackView.pop()
    }

    Component.onCompleted: {
        // Don't show any highlighted item until interacting with them.
        // We do this here instead of onActivated to avoid losing the user's
        // selection when backing out of a different page of the app.
        currentIndex = -1
    }

    StackView.onActivated: {
        appModel.computerLost.connect(computerLost)
        activated = true

        // Highlight the first item if a gamepad is connected
        if (currentIndex === -1 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            currentIndex = 0
        }

        if (!showGames && !showHiddenGames) {
            // Check if there's a direct launch app
            var directLaunchAppIndex = model.getDirectLaunchAppIndex();
            if (directLaunchAppIndex >= 0) {
                // Start the direct launch app if nothing else is running
                currentIndex = directLaunchAppIndex
                currentItem.launchOrResumeSelectedApp(false)

                // Set showGames so we will not loop when the stream ends
                showGames = true
            }
        }
    }

    StackView.onDeactivating: {
        appModel.computerLost.disconnect(computerLost)
        activated = false
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import StreamingPreferences 1.0
import AppModel 1.0; AppModel {}', parent, '')
        model.initialize(ComputerManager, computerIndex, showHiddenGames)
        return model
    }

    model: appModel

    delegate: NavigableItemDelegate {
        width: 240; height: 420;
        padding: 0
        readonly property string appName: model.name
        readonly property bool appRunning: model.running
        objectName: model.sleepAction ? "hostSleepTile" : ""
        grid: appGrid

        property alias appContextMenu: appContextMenuLoader.item
        property alias appNameText: appNameTextLoader.item

        // Dim the app if it's hidden
        opacity: model.hidden ? 0.4 : 1.0

        Image {
            property bool isPlaceholder: false

            id: appIcon
            x: 1; y: 1
            width: parent.width - 2
            height: 300
            fillMode: Image.PreserveAspectCrop
            source: model.boxart

            onSourceSizeChanged: {
                // Nearly all of Nvidia's official box art does not match the dimensions of placeholder
                // images, however the one known exception is Overcooked. Therefore, we only execute
                // the image size checks if this is not an app collector game. We know the officially
                // supported games all have box art, so this check is not required.
                if (!model.isAppCollectorGame &&
                    ((sourceSize.width === 130 && sourceSize.height === 180) || // GFE 2.0 placeholder image
                     (sourceSize.width === 628 && sourceSize.height === 888) || // GFE 3.0 placeholder image
                     (sourceSize.width === 200 && sourceSize.height === 266)))  // Our no_app_image.png
                {
                    isPlaceholder = true
                }
                else
                {
                    isPlaceholder = false
                }

            }

            // Display a tooltip with the full name if it's truncated
            ToolTip.text: model.name
            ToolTip.delay: 1000
            ToolTip.timeout: 5000
            ToolTip.visible: (parent.hovered || parent.highlighted) && (!appNameText || appNameText.truncated)
        }

        // Placeholder art: the app's name set large on an ash block
        Rectangle {
            visible: appIcon.isPlaceholder || appIcon.status !== Image.Ready
            anchors.fill: appIcon
            color: Theme.ash
        }

        // Label, title, caption and arrow under the art
        Column {
            anchors { left: parent.left; right: parent.right; top: appIcon.bottom; margins: 16 }
            spacing: 0
            Rectangle {
                width: tagText.implicitWidth + 14; height: 20
                color: model.running ? Theme.marigold : Theme.ash
                border.width: model.running ? 0 : 1
                border.color: Theme.cardRule
                Text { id: tagText; anchors.centerIn: parent; text: model.running ? qsTr("RUNNING NOW") : qsTr("APP"); color: Theme.ink; font.family: Theme.monoFont; font.pixelSize: 11 }
            }
            Item { width: 1; height: 10 }
            Text { width: parent.width; text: model.name; color: Theme.ink; font.family: Theme.sansFont; font.weight: Font.Bold; font.pixelSize: 20; font.letterSpacing: -0.4; elide: Text.ElideRight }
            Item { width: 1; height: 4 }
            Text { width: parent.width; text: model.running ? qsTr("resume · quit from Options") : qsTr("launch"); color: Theme.stone; font.family: Theme.monoFont; font.pixelSize: 12; elide: Text.ElideRight }
        }
        Text {
            anchors { right: parent.right; bottom: parent.bottom; margins: 14 }
            text: "→"; color: Theme.ink; font.family: Theme.sansFont; font.pixelSize: 18
        }

        Loader {
            id: appNameTextLoader
            active: appIcon.isPlaceholder

            // This loader is not asynchronous to avoid noticeable differences
            // in the time in which the text loads for each game.

            width: appIcon.width
            height: appIcon.height

            anchors.left: appIcon.left
            anchors.right: appIcon.right
            anchors.bottom: appIcon.bottom

            sourceComponent: Label {
                id: appNameText
                text: model.name
                color: Theme.ink
                font.family: Theme.sansFont
                font.weight: Font.Bold
                font.pixelSize: 34
                font.letterSpacing: -1.5
                leftPadding: 20
                rightPadding: 20
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }
        }

        // displayOverride: -2 use the preference, -1 host decides, 0 physical, 1 virtual (Apollo hosts)
        function launchOrResumeSelectedApp(quitExistingApp, displayOverride)
        {
            if (displayOverride === undefined) displayOverride = -2
            if (model.sleepAction) {
                if (!appGrid.sleepPending) sleepDialog.open()
                return
            }
            if (model.notice) {
                // Apollo permission placeholder: its title says what to enable on the host.
                noticeDialog.text = model.name
                noticeDialog.open()
                return
            }
            var verb = appModel.launchVerbForApp(index)
            if (verb === 2) {
                if (quitExistingApp) {
                    quitAppDialog.appName = appModel.getRunningAppName()
                    quitAppDialog.segueToStream = true
                    quitAppDialog.nextAppName = model.name
                    quitAppDialog.nextAppIndex = index
                    quitAppDialog.nextDisplayOverride = displayOverride
                    quitAppDialog.open()
                }

                return
            }

            var component = Qt.createComponent("StreamSegue.qml")
            var segue = component.createObject(stackView, {
                                                   "appName": model.name,
                                                   "session": appModel.createSessionForApp(index, displayOverride),
                                                   "isResume": verb === 1
                                               })
            stackView.push(segue)
        }

        onClicked: {
            // Only allow clicking on the box art for non-running games.
            // For running games, buttons will appear to resume or quit which
            // will handle starting the game and clicks on the box art will
            // be ignored.
            launchOrResumeSelectedApp(true)
        }

        onPressAndHold: {
            // popup() ensures the menu appears under the mouse cursor
            if (model.sleepAction) {
                if (!appGrid.sleepPending) sleepDialog.open()
                return
            }
            if (appContextMenu.popup) {
                appContextMenu.popup()
            }
            else {
                // Qt 5.9 doesn't have popup()
                appContextMenu.open()
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton;
            onClicked: {
                parent.pressAndHold()
            }
        }

        Keys.onReturnPressed: {
            // Open the app context menu if activated via the gamepad or keyboard
            // for running games. If the game isn't running, the above onClicked
            // method will handle the launch.
            if (model.running) {
                // This will be keyboard/gamepad driven so use
                // open() instead of popup()
                appContextMenu.open()
            }
        }

        Keys.onEnterPressed: {
            // Open the app context menu if activated via the gamepad or keyboard
            // for running games. If the game isn't running, the above onClicked
            // method will handle the launch.
            if (model.running) {
                // This will be keyboard/gamepad driven so use
                // open() instead of popup()
                appContextMenu.open()
            }
        }

        // Controller X (sent as F13) keeps opening this menu, like Start.
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_F13) {
                if (model.sleepAction) {
                    if (!appGrid.sleepPending) sleepDialog.open()
                } else appContextMenu.open()
                event.accepted = true
            }
        }

        Keys.onMenuPressed: {
            // This will be keyboard/gamepad driven so use open() instead of popup()
            if (model.sleepAction) {
                if (!appGrid.sleepPending) sleepDialog.open()
            } else appContextMenu.open()
        }

        function launchOnDisplay(virtualDisplay) {
            if (virtualDisplay === 1 && !appModel.apolloVirtualDisplayReady()) {
                vdNotReadyDialog.appIndex = index
                vdNotReadyDialog.launch = function() { launchOrResumeSelectedApp(true, 1) }
                vdNotReadyDialog.open()
                return
            }
            launchOrResumeSelectedApp(true, virtualDisplay)
        }

        function doQuitGame() {
            quitAppDialog.appName = appModel.getRunningAppName()
            quitAppDialog.segueToStream = false
            quitAppDialog.open()
        }

        Loader {
            id: appContextMenuLoader
            asynchronous: true
            active: !model.sleepAction
            sourceComponent: NavigableMenu {
                id: appContextMenu
                initiator: appContextMenuLoader.parent
                NavigableMenuItem {
                    text: model.running ? qsTr("Resume Game") : qsTr("Launch Game")
                    onTriggered: launchOrResumeSelectedApp(true)
                }
                NavigableMenuItem {
                    text: qsTr("Launch on Virtual Display")
                    onTriggered: launchOnDisplay(1)
                    visible: !model.running && !model.notice &&
                             (appModel.apolloDisplayMenu() === 1 || appModel.apolloDisplayMenu() === 2)
                    height: visible ? implicitHeight : 0
                }
                NavigableMenuItem {
                    text: qsTr("Launch on Physical Display")
                    onTriggered: launchOnDisplay(0)
                    visible: !model.running && !model.notice &&
                             (appModel.apolloDisplayMenu() === 1 || appModel.apolloDisplayMenu() === 3)
                    height: visible ? implicitHeight : 0
                }
                NavigableMenuItem {
                    text: qsTr("Quit Game")
                    onTriggered: doQuitGame()
                    visible: model.running
                }
                NavigableMenuItem {
                    checkable: true
                    checked: model.directLaunch
                    text: qsTr("Direct Launch")
                    onTriggered: appModel.setAppDirectLaunch(model.index, !model.directLaunch)
                    enabled: !model.hidden

                    ToolTip.text: qsTr("Launch this app immediately when the host is selected, bypassing the app selection grid.")
                    ToolTip.delay: 1000
                    ToolTip.timeout: 3000
                    ToolTip.visible: hovered
                }
                NavigableMenuItem {
                    checkable: true
                    checked: model.hidden
                    text: qsTr("Hide Game")
                    onTriggered: appModel.setAppHidden(model.index, !model.hidden)
                    enabled: model.hidden || (!model.running && !model.directLaunch)

                    ToolTip.text: qsTr("Hide this game from the app grid. To access hidden games, right-click on the host and choose %1.").arg(qsTr("View All Apps"))
                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 5
        visible: appGrid.count === 0

        Label {
            text: qsTr("This computer doesn't seem to have any applications or some applications are hidden")
            color: Theme.textSecondary
            font.family: Theme.headingFont
            font.pixelSize: Theme.px(24)
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }

    NavigableMessageDialog {
        id: quitAppDialog
        property string appName : ""
        property bool segueToStream : false
        property string nextAppName: ""
        property int nextAppIndex: 0
        property int nextDisplayOverride: -2
        text:qsTr("Are you sure you want to quit %1? Any unsaved progress will be lost.").arg(appName)
        standardButtons: Dialog.Yes | Dialog.No

        function quitApp() {
            var component = Qt.createComponent("QuitSegue.qml")
            var params = {"appName": appName, "quitRunningAppFn": function() { appModel.quitRunningApp() }}
            if (segueToStream) {
                // Store the session and app name if we're going to stream after
                // successfully quitting the old app.
                params.nextAppName = nextAppName
                params.nextSession = appModel.createSessionForApp(nextAppIndex, nextDisplayOverride)
            }
            else {
                params.nextAppName = null
                params.nextSession = null
            }

            stackView.push(component.createObject(stackView, params))
        }

        onAccepted: quitApp()
    }

    NavigableMessageDialog {
        id: sleepDialog
        objectName: "hostSleepConfirmation"
        title: qsTr("Put PC to Sleep")
        text: qsTr("Put this host PC to sleep? All host applications and streaming sessions must be closed first. You will need a way to wake the PC again.")
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            if (!appGrid.sleepPending) {
                appGrid.sleepPending = true
                appModel.requestHostSleep()
            }
        }
    }

    NavigableMessageDialog {
        id: vdNotReadyDialog
        property int appIndex: -1
        property var launch: null
        title: qsTr("Virtual display not ready")
        text: qsTr("The host reports that its virtual display driver is not ready. The launch may fall back to the physical display or fail. Launch anyway?")
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: if (launch) launch()
    }

    NavigableMessageDialog {
        id: noticeDialog
        objectName: "apolloPermissionNotice"
        title: qsTr("Host permission needed")
        standardButtons: Dialog.Ok
    }

    NavigableMessageDialog {
        id: sleepResult
        objectName: "hostSleepResult"
        title: qsTr("Host Sleep")
        standardButtons: Dialog.Ok
    }

    ScrollBar.vertical: ScrollBar {}
}
