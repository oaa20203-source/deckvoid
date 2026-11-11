import QtQuick 2.15
import QtQuick.Controls 2.15
import QtCore

import ComputerModel 1.0
import AppModel 1.0
import ComputerManager 1.0
import StreamingPreferences 1.0
import DeckVoidTheme 1.0

// Home (design/mockups/home-glass.html): built around one PC. The left column holds
// the name and the settings changed most; the right has the PC as a glass tile and
// its apps below, most recently used first. Everything turns grey while the PC is off.
Item {
    id: home
    objectName: qsTr("Home")

    // The mockup is 100 units wide at 16:10; the whole page scales with the window
    readonly property real cq: Math.min(width, height * 1.6) / 100

    property ComputerModel computerModel: createModel()
    property var pc: null           // the PC shown: a paired one if there is one
    property var appModel: null
    property var desktopApp: null   // started by the button on the PC tile
    property var tiles: []          // the other apps, most recently used first
    property bool devReady: false   // developer aid: show the PC as ready

    readonly property bool hasPc: pc !== null
    readonly property bool pcOnline: hasPc && (pc.online || devReady)
    readonly property bool pcReady: pcOnline && (pc.paired || devReady)
    readonly property bool pcOff: hasPc && !pcOnline

    readonly property string statusText: {
        if (!hasPc) return qsTr("No PC yet")
        if (devReady) return qsTr("Ready")
        if (pc.statusUnknown) return qsTr("Checking…")
        if (!pc.online) return qsTr("Asleep")
        if (!pc.paired) return qsTr("Not paired")
        if (pc.runningApp !== "") return qsTr("Running %1").arg(pc.runningApp)
        return qsTr("Ready")
    }
    readonly property string buttonText: {
        if (!hasPc) return qsTr("Add a PC")
        if (devReady) return qsTr("Stream desktop")
        if (pc.statusUnknown) return ""
        if (!pc.online) return pc.wakeable ? qsTr("Wake") : ""
        if (!pc.paired) return qsTr("Pair")
        return desktopApp ? qsTr("Stream desktop") : ""
    }

    function createModel() {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
        model.initialize(ComputerManager)
        return model
    }

    // Most recent launches, per PC: {"<pc uuid>": {"<app id>": <time in ms>}}
    Settings {
        id: store
        category: "home"
        property string recents: "{}"
    }
    function recentsFor(uuid) {
        try { return JSON.parse(store.recents)[uuid] || {} } catch (e) { return {} }
    }
    function remember(appId) {
        var all = {}
        try { all = JSON.parse(store.recents) } catch (e) {}
        var uuid = computerModel.uuidAt(pc.idx)
        if (!all[uuid]) all[uuid] = {}
        all[uuid][appId] = Date.now()
        store.recents = JSON.stringify(all)
        refreshTiles()
    }
    function ago(ms) {
        var minutes = Math.floor((Date.now() - ms) / 60000)
        if (minutes < 1) return qsTr("just now")
        if (minutes < 60) return qsTr("%1 min ago").arg(minutes)
        if (minutes < 60 * 24) return qsTr("%1 h ago").arg(Math.floor(minutes / 60))
        return qsTr("%1 d ago").arg(Math.floor(minutes / (60 * 24)))
    }

    // The PC list, as objects that follow the model
    Instantiator {
        id: pcs
        model: home.computerModel
        delegate: QtObject {
            property int idx: index
            property string name: model.name
            property bool online: model.online
            property bool paired: model.paired
            property bool wakeable: model.wakeable
            property bool statusUnknown: model.statusUnknown
            property string runningApp: model.runningApp
            onPairedChanged: home.pick()
        }
        onObjectAdded: home.pick()
        onObjectRemoved: home.pick()
    }
    function pick() {
        var best = null
        for (var i = 0; i < pcs.count; i++) {
            var o = pcs.objectAt(i)
            if (o && (!best || (o.paired && !best.paired))) best = o
        }
        var changed = best !== pc
        pc = best
        if (changed) rebuildApps()
    }

    function rebuildApps() {
        if (appModel) {
            appModel.destroy()
            appModel = null
        }
        // The app list is remembered from the last time the PC was on, so it shows (in grey) while the PC is off
        if (pc) {
            var model = Qt.createQmlObject('import AppModel 1.0; AppModel {}', home, '')
            model.initialize(ComputerManager, pc.idx, false)
            appModel = model
        }
        refreshTiles()
    }

    Instantiator {
        id: apps
        model: home.appModel
        delegate: QtObject {
            property int idx: index
            property string name: model.name
            property int appid: model.appid
            property bool running: model.running
            property bool special: model.sleepAction || model.notice
        }
        onObjectAdded: home.refreshTiles()
        onObjectRemoved: home.refreshTiles()
    }
    function refreshTiles() {
        var recent = pc ? recentsFor(computerModel.uuidAt(pc.idx)) : {}
        var list = []
        var desktop = null
        for (var i = 0; i < apps.count; i++) {
            var a = apps.objectAt(i)
            if (!a || a.special) continue
            if (!desktop && /^desktop$/i.test(a.name)) { desktop = a; continue }
            list.push({ "app": a, "when": recent[a.appid] || 0 })
        }
        list.sort(function(x, y) { return y.when - x.when || x.app.idx - y.app.idx })
        desktopApp = desktop
        tiles = list
    }

    function launch(app) {
        if (!pcReady || !appModel || !app) return
        var verb = appModel.launchVerbForApp(app.idx)
        if (verb === 2) {
            // Another app is running on the PC: ask before quitting it
            quitAppDialog.next = app
            quitAppDialog.appName = appModel.getRunningAppName()
            quitAppDialog.open()
            return
        }
        remember(app.appid)
        var segue = Qt.createComponent("StreamSegue.qml").createObject(stackView, {
            "appName": app.name,
            "session": appModel.createSessionForApp(app.idx, -2),
            "isResume": verb === 1
        })
        stackView.push(segue)
    }

    function startPairing() {
        var pin = computerModel.generatePinString()
        computerModel.pairComputer(pc.idx, pin)
        openPair(pc.name, pin)
    }
    function openPair(name, pin) {
        stackView.push(Qt.createComponent("PairView.qml").createObject(stackView, {
            "computerModel": computerModel, "pcName": name, "pin": pin
        }))
    }
    // Developer aid (DECKVOID_START_VIEW=pair)
    function openPairPreview() { openPair(hasPc ? pc.name : "Gaming PC", "4719") }

    function primary() {
        if (!hasPc) addPcDialog.open()
        else if (devReady || pc.statusUnknown) return
        else if (!pc.online) { if (pc.wakeable) computerModel.wakeComputer(pc.idx) }
        else if (!pc.paired) startPairing()
        else launch(desktopApp)
    }

    Keys.onReturnPressed: primary()
    Keys.onEnterPressed: primary()

    NavigableMessageDialog {
        id: quitAppDialog
        property string appName: ""
        property var next: null
        text: qsTr("Are you sure you want to quit %1? Any unsaved progress will be lost.").arg(appName)
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            var app = next
            home.remember(app.appid)
            stackView.push(Qt.createComponent("QuitSegue.qml").createObject(stackView, {
                "appName": appName,
                "quitRunningAppFn": function() { home.appModel.quitRunningApp() },
                "nextAppName": app.name,
                "nextSession": home.appModel.createSessionForApp(app.idx, -2)
            }))
        }
    }

    // ---- Left column -------------------------------------------------------
    component QuickRow: Item {
        property alias label: rowLabel.text
        property alias value: rowValue.text
        property bool rule: true
        default property alias content: rowSlot.data
        width: parent.width
        height: 3.3 * home.cq
        Text {
            id: rowLabel
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.glassMuted
            font.family: Theme.sansFont
            font.pixelSize: 1.6 * home.cq
        }
        Text {
            id: rowValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.glassText
            font.family: Theme.sansFont
            font.pixelSize: 1.6 * home.cq
        }
        Item { id: rowSlot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }
        Rectangle { visible: parent.rule; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.glassLine }
    }

    Item {
        id: side
        x: 1.8 * cq
        y: 4.4 * cq
        width: 21.1 * cq
        height: parent.height - y - 1.8 * cq

        Rectangle {
            id: namePill
            width: parent.width
            height: nameText.implicitHeight + 2 * cq
            radius: 1.5 * cq
            color: Theme.glassText
            Text {
                id: nameText
                x: 1.5 * cq
                anchors.verticalCenter: parent.verticalCenter
                text: "!ink"
                color: "#FFFFFF"
                font.family: Theme.sansFont
                font.pixelSize: 1.9 * cq
            }
        }

        Column {
            anchors.top: namePill.bottom
            anchors.topMargin: 1.2 * cq
            x: 1.5 * cq
            width: parent.width - 3 * cq

            QuickRow { label: qsTr("Frame rate"); value: qsTr("%1 fps").arg(StreamingPreferences.fps) }
            QuickRow { label: qsTr("Bitrate"); value: qsTr("%1 Mbps").arg(Math.round(StreamingPreferences.bitrateKbps / 100) / 10); rule: false; height: 2.9 * home.cq }
            Rectangle {
                width: parent.width
                height: 0.5 * cq
                radius: height / 2
                color: Theme.glassLine
                clip: true
                Rectangle {
                    width: parent.width * Math.min(1, StreamingPreferences.bitrateKbps / 150000)
                    height: parent.height
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.glassOrange }
                        GradientStop { position: 1; color: Theme.glassSage }
                    }
                    // The same bar in grey while the PC is off
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        opacity: home.pcOff ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 500 } }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#878787" }
                            GradientStop { position: 1; color: "#C3C3C3" }
                        }
                    }
                }
            }
            Item { width: 1; height: 0.9 * cq }
            Rectangle { width: parent.width; height: 1; color: Theme.glassLine }
            QuickRow {
                label: qsTr("Adaptive bitrate")
                Rectangle {
                    width: 3.2 * home.cq
                    height: 1.8 * home.cq
                    radius: height / 2
                    color: StreamingPreferences.adaptiveBitrate ? Theme.glassText : Theme.glassTrack
                    Rectangle {
                        width: 1.3 * home.cq
                        height: width
                        radius: width / 2
                        y: 0.25 * home.cq
                        x: StreamingPreferences.adaptiveBitrate ? parent.width - width - 0.25 * home.cq : 0.25 * home.cq
                        color: "#FFFFFF"
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -0.6 * home.cq
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            StreamingPreferences.adaptiveBitrate = !StreamingPreferences.adaptiveBitrate
                            StreamingPreferences.save()
                        }
                    }
                }
            }
            Item { width: 1; height: 1.4 * cq }
            Text {
                text: qsTr("All settings") + "  →"
                color: Theme.glassText
                font.family: Theme.sansFont
                font.pixelSize: 1.6 * cq
                MouseArea { anchors.fill: parent; anchors.margins: -0.6 * home.cq; cursorShape: Qt.PointingHandCursor; onClicked: window.showSettings() }
            }
        }

        Text {
            x: 1.5 * cq
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0.6 * cq
            text: "+  " + qsTr("Add a PC")
            color: Theme.glassFaint
            font.family: Theme.sansFont
            font.pixelSize: 1.9 * cq
            MouseArea { anchors.fill: parent; anchors.margins: -0.6 * home.cq; cursorShape: Qt.PointingHandCursor; onClicked: addPcDialog.open() }
        }
    }

    // ---- The PC and its apps -----------------------------------------------
    Item {
        id: main
        x: 24.3 * cq
        y: 4.4 * cq
        width: parent.width - x - 1.8 * cq
        height: parent.height - y - 1.8 * cq
        readonly property real gap: 1.4 * home.cq
        readonly property real heroHeight: (height - gap) * 1.6 / 2.6
        readonly property real tileWidth: (width - 2 * gap) / 3

        FlutedGlass {
            id: hero
            width: parent.width
            height: main.heroHeight
            radius: 2.2 * home.cq
            fluteWidth: 1.6 * home.cq
            variant: 0
            off: home.pcOff

            Column {
                x: 2.2 * home.cq
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1.9 * home.cq
                width: parent.width - 4.4 * home.cq
                Text {
                    text: home.statusText
                    color: Theme.glassText
                    font.family: Theme.sansFont
                    font.pixelSize: 1.6 * home.cq
                }
                Text {
                    width: parent.width
                    text: home.hasPc ? home.pc.name : qsTr("Add your PC")
                    color: Theme.glassText
                    elide: Text.ElideRight
                    font.family: Theme.sansFont
                    font.weight: Font.Medium
                    font.pixelSize: 4.9 * home.cq
                    font.letterSpacing: -0.035 * 4.9 * home.cq
                }
                Item { width: 1; height: 1.2 * home.cq; visible: heroButton.visible }
                Rectangle {
                    id: heroButton
                    visible: home.buttonText !== ""
                    width: heroButtonText.implicitWidth + 4.4 * home.cq
                    height: heroButtonText.implicitHeight + 1.6 * home.cq
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, heroButtonArea.containsMouse ? 1 : 0.85)
                    Text {
                        id: heroButtonText
                        anchors.centerIn: parent
                        text: home.buttonText
                        color: Theme.glassText
                        font.family: Theme.sansFont
                        font.pixelSize: 1.8 * home.cq
                    }
                    MouseArea { id: heroButtonArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: home.primary() }
                }
            }
        }

        // Apps, most recently used on the far left with the glass
        ListView {
            id: appRow
            y: main.heroHeight + main.gap
            width: parent.width
            height: parent.height - y
            orientation: ListView.Horizontal
            spacing: main.gap
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: home.tiles

            delegate: Item {
                id: tile
                readonly property var app: modelData.app
                readonly property bool lead: index === 0
                width: main.tileWidth
                height: appRow.height

                Rectangle {
                    anchors.fill: parent
                    radius: 2.2 * home.cq
                    color: Theme.glassPanel
                    visible: !tile.lead
                }
                Loader {
                    anchors.fill: parent
                    active: tile.lead
                    sourceComponent: FlutedGlass {
                        radius: 2.2 * home.cq
                        fluteWidth: 1.6 * home.cq
                        variant: 1
                        seed: 2.4
                        off: home.pcOff
                    }
                }
                Column {
                    x: 2.2 * home.cq
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1.9 * home.cq
                    width: parent.width - 3.2 * home.cq
                    Text {
                        text: tile.app.running ? qsTr("Running")
                            : (tile.lead && modelData.when > 0 ? qsTr("Last played · %1").arg(home.ago(modelData.when)) : qsTr("App"))
                        color: tile.lead ? Theme.glassText : Theme.glassMuted
                        font.family: Theme.sansFont
                        font.pixelSize: 1.6 * home.cq
                    }
                    Text {
                        width: parent.width
                        text: tile.app.name
                        color: Theme.glassText
                        elide: Text.ElideRight
                        font.family: Theme.sansFont
                        font.weight: Font.Medium
                        font.pixelSize: 2.5 * home.cq
                        font.letterSpacing: -0.02 * 2.5 * home.cq
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.launch(tile.app) }
            }
        }
    }
}
