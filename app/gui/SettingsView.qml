import QtQuick 2.15
import QtQuick.Controls 2.15

import StreamingPreferences 1.0
import SystemProperties 1.0
import AutoUpdateChecker 1.0
import DeckVoidTheme 1.0

// Settings (design/mockups/settings.html): categories on the left, a strip of glass
// naming the current one, and two panels of rows. Every row is described in tabs()
// by the preference it reads and writes; the delegate below draws it.
Item {
    id: settingsPage
    objectName: qsTr("Settings")

    readonly property real cq: Math.min(width, height * 1.6) / 100
    property string category: "Picture"
    readonly property var tabList: tabs()
    readonly property var current: {
        for (var i = 0; i < tabList.length; i++) {
            if (tabList[i].name === category) return tabList[i]
        }
        return tabList[0]
    }
    readonly property size nativeRes: nativeSize()

    StackView.onDeactivating: StreamingPreferences.save()
    Component.onDestruction: StreamingPreferences.save()

    function nativeSize() {
        SystemProperties.refreshDisplays()
        var r = SystemProperties.getNativeResolution(0)
        return r.width === 0 ? Qt.size(1280, 800) : Qt.size(r.width, r.height)
    }
    // While "use the default bitrate" is in effect, it follows the resolution and frame rate
    function fitBitrate() {
        if (StreamingPreferences.autoAdjustBitrate) {
            StreamingPreferences.bitrateKbps = StreamingPreferences.getDefaultBitrate(
                StreamingPreferences.width, StreamingPreferences.height,
                StreamingPreferences.fps, StreamingPreferences.enableYUV444)
        }
    }
    function setSize(w, h) {
        StreamingPreferences.width = w
        StreamingPreferences.height = h
        fitBitrate()
    }

    // Row helpers. p is the preference name; inverted switches show the opposite.
    function tog(label, p, inverted) {
        return { "type": "tog", "label": label,
                 "get": function() { return inverted ? !StreamingPreferences[p] : StreamingPreferences[p] },
                 "set": function(v) { StreamingPreferences[p] = inverted ? !v : v } }
    }
    function seg(label, p, options, values, wide) {
        return { "type": "seg", "label": label, "wide": wide === true,
                 "options": function() { return options }, "values": function() { return values },
                 "get": function() { return StreamingPreferences[p] },
                 "set": function(v) { StreamingPreferences[p] = v } }
    }

    function tabs() {
        var P = StreamingPreferences
        var sizes = [[1920, 1080], [2560, 1440], [nativeRes.width, nativeRes.height]]
        var resolution = {
            "type": "seg", "label": qsTr("Resolution"), "wide": true, "custom": true,
            "options": function() { return ["1080p", "1440p", qsTr("Native"), qsTr("Custom")] },
            "values": function() { return [0, 1, 2, 3] },
            "get": function() {
                // Native wins when it is also 1080p or 1440p
                for (var i = 2; i >= 0; i--) {
                    if (P.width === sizes[i][0] && P.height === sizes[i][1]) return i
                }
                return 3
            },
            "set": function(i) { if (i < 3) setSize(sizes[i][0], sizes[i][1]) }
        }
        var frameRate = {
            "type": "seg", "label": qsTr("Frame rate"), "wide": false,
            // A rate set elsewhere (a custom one) stays visible as a fourth choice
            "options": function() { return [60, 90, 120].indexOf(P.fps) < 0 ? ["60", "90", "120", String(P.fps)] : ["60", "90", "120"] },
            "values": function() { return [60, 90, 120].indexOf(P.fps) < 0 ? [60, 90, 120, P.fps] : [60, 90, 120] },
            "get": function() { return P.fps },
            "set": function(v) { P.fps = v; fitBitrate() }
        }
        var scale = {
            "type": "seg", "label": qsTr("Virtual display scale"), "wide": true,
            "options": function() { return ["100%", "125%", "150%", [100, 125, 150].indexOf(P.apolloScaleFactor) < 0 ? P.apolloScaleFactor + "%" : qsTr("More")] },
            "values": function() { return [100, 125, 150, [100, 125, 150].indexOf(P.apolloScaleFactor) < 0 ? P.apolloScaleFactor : -1] },
            "get": function() { return P.apolloScaleFactor },
            // "More" steps through the less common sizes
            "set": function(v) {
                var more = [175, 200, 50, 75]
                P.apolloScaleFactor = v === -1 ? more[0] : (more.indexOf(v) >= 0 ? more[(more.indexOf(v) + 1) % more.length] : v)
            }
        }
        var language = {
            "type": "seg", "label": qsTr("Language"), "wide": false, "menu": true,
            "options": function() { return [languageName(P.language), qsTr("More")] },
            "values": function() { return [P.language, -1] },
            "get": function() { return P.language },
            "set": function(v) { if (v === -1) languageMenu.popup() }
        }
        var mac = Qt.platform.os === "osx"
        var renderer = seg(qsTr("Renderer"), "rendererSelection",
                           mac ? [qsTr("Auto"), "Metal", "Vulkan", qsTr("Layer")] : [qsTr("Auto"), "Vulkan"],
                           mac ? [P.RS_AUTO, P.RS_METAL, P.RS_VULKAN, P.RS_AVSBDL] : [P.RS_AUTO, P.RS_VULKAN], true)

        var advancedRight = [
            tog(qsTr("Performance stats while streaming"), "showPerformanceOverlay"),
            tog(qsTr("Frametime graph while streaming"), "showFrametimeGraph"),
            tog(qsTr("Reduce judder"), "smoothVrrFrameTiming"),
            tog(qsTr("Absorb microstutter"), "absorbVrrMicrostutter"),
            tog(qsTr("Trace VRR frames"), "traceVrrFrames"),
            { "type": "act", "label": qsTr("Diagnostics folder"), "text": qsTr("Open"), "run": function() { P.openDiagnosticsFolder() } },
            // Calibration, custom frame rates and the VRR tuning tools still live on the previous screen
            { "type": "act", "label": qsTr("Classic settings"), "text": qsTr("Open"), "run": function() { window.showClassicSettings() } }
        ]
        if (Qt.platform.os === "linux") {
            advancedRight.splice(5, 0, tog(qsTr("High-performance GPU power"), "highPerformanceGpuPower"))
        }

        return [
            { "name": "Picture", "title": qsTr("Picture"), "panels": [
                { "title": qsTr("Stream"), "rows": [
                    resolution, frameRate,
                    { "type": "sld", "label": qsTr("Bitrate") },
                    tog(qsTr("Adaptive bitrate"), "adaptiveBitrate"),
                    seg(qsTr("Video codec"), "videoCodecConfig", [qsTr("Auto"), "H.264", "HEVC", "AV1"],
                        [P.VCC_AUTO, P.VCC_FORCE_H264, P.VCC_FORCE_HEVC, P.VCC_FORCE_AV1], true) ] },
                { "title": qsTr("Display"), "rows": [
                    seg(qsTr("Display mode"), "windowMode", [qsTr("Full screen"), qsTr("Borderless"), qsTr("Windowed")],
                        [P.WM_FULLSCREEN, P.WM_FULLSCREEN_DESKTOP, P.WM_WINDOWED], true),
                    tog(qsTr("V-Sync"), "enableVsync"), tog(qsTr("Frame pacing"), "framePacing"), tog(qsTr("VRR"), "enableVrr"),
                    tog(qsTr("HDR"), "enableHdr"), tog(qsTr("YUV 4:4:4"), "enableYUV444") ] } ] },
            { "name": "Audio", "title": qsTr("Audio"), "panels": [
                { "title": qsTr("Output"), "rows": [
                    seg(qsTr("Speaker layout"), "audioConfig", [qsTr("Stereo"), qsTr("5.1 surround"), qsTr("7.1 surround")],
                        [P.AC_STEREO, P.AC_51_SURROUND, P.AC_71_SURROUND], true) ] },
                { "title": qsTr("Muting"), "rows": [
                    tog(qsTr("Mute PC speakers while streaming"), "playAudioOnHost", true),
                    tog(qsTr("Mute when in the background"), "muteOnFocusLoss") ] } ] },
            { "name": "Input", "title": qsTr("Input"), "panels": [
                { "title": qsTr("Mouse"), "rows": [
                    tog(qsTr("Desktop mouse mode"), "absoluteMouseMode"), tog(qsTr("Swap left and right buttons"), "swapMouseButtons"),
                    tog(qsTr("Reverse scroll direction"), "reverseScrollDirection"), tog(qsTr("Touchscreen as trackpad"), "absoluteTouchMode", true) ] },
                { "title": qsTr("Keyboard"), "rows": [
                    seg(qsTr("Capture system shortcuts"), "captureSysKeysMode", [qsTr("Off"), qsTr("In full screen"), qsTr("Always")],
                        [P.CSK_OFF, P.CSK_FULLSCREEN, P.CSK_ALWAYS], true) ] } ] },
            { "name": "Controllers", "title": qsTr("Controllers"), "panels": [
                { "title": qsTr("Gamepad"), "rows": [
                    tog(qsTr("Swap A/B and X/Y"), "swapFaceButtons"), tog(qsTr("Keep controller 1 connected"), "multiController", true),
                    tog(qsTr("Hold Start to control the mouse"), "gamepadMouse"), tog(qsTr("Use controller in the background"), "backgroundGamepad") ] },
                { "title": qsTr("Steam Controller"), "rows": [
                    tog(qsTr("Drive Steam Controller directly"), "steamControllerDriver"), tog(qsTr("Gyro and accelerometer"), "steamControllerMotion"),
                    tog(qsTr("Trackpads as touchpad halves"), "steamControllerSplitPads"), tog(qsTr("Stretch sticks to the rim"), "steamControllerStickStretch"),
                    seg(qsTr("Grip buttons"), "steamControllerGrips", [qsTr("Paddles"), "DualShock", qsTr("Off")],
                        [P.SCG_PADDLES, P.SCG_DS4, P.SCG_OFF], true) ] } ] },
            { "name": "Haptics", "title": qsTr("Haptics"), "panels": [
                { "title": qsTr("Rumble"), "rows": [
                    seg(qsTr("Hold host rumble for"), "steamControllerRumbleHold", ["0.25 s", "0.5 s", "1 s", "2 s", qsTr("Max")], [250, 500, 1000, 2000, 0], true) ] },
                { "title": qsTr("Steam Controller over Bluetooth"), "rows": [
                    seg(qsTr("Pad click boost"), "steamControllerHapticBoost", [qsTr("Off"), "+6 dB", "+12 dB", "+20 dB"], [0, 6, 12, 20], true),
                    seg(qsTr("Pad slide pulse length"), "steamControllerHapticPulseScale", ["100%", "150%", "200%", "300%"], [100, 150, 200, 300], true),
                    seg(qsTr("Haptic gain"), "steamControllerHapticMasterGain", [qsTr("Off"), "+6 dB", "+12 dB"], [0, 6, 12], true) ] } ] },
            { "name": "Host", "title": qsTr("Host"), "panels": [
                { "title": qsTr("Session"), "rows": [
                    tog(qsTr("Optimise game settings"), "gameOptimizations"), tog(qsTr("Quit app when the stream ends"), "quitAppAfter"),
                    { "type": "txt", "label": qsTr("Client name"),
                      "get": function() { return P.apolloClientName }, "set": function(v) { P.apolloClientName = v } } ] },
                { "title": "Apollo", "rows": [
                    seg(qsTr("Display for launches"), "apolloVirtualDisplay", [qsTr("Host decides"), qsTr("Virtual"), qsTr("Physical")], [-1, 1, 0], true),
                    scale,
                    seg(qsTr("Clipboard sync"), "apolloClipboardSync", [qsTr("Off"), qsTr("Manual"), qsTr("Automatic")], [0, 1, 2], true) ] } ] },
            { "name": "App", "title": qsTr("App"), "panels": [
                { "title": qsTr("Window"), "rows": [
                    language,
                    seg(qsTr("Window mode"), "uiDisplayMode", [qsTr("Windowed"), qsTr("Maximised"), qsTr("Full screen")],
                        [P.UI_WINDOWED, P.UI_MAXIMIZED, P.UI_FULLSCREEN], true),
                    tog(qsTr("Keep display awake while streaming"), "keepAwake") ] },
                { "title": qsTr("Notices"), "rows": [
                    tog(qsTr("Connection quality warnings"), "connectionWarnings"), tog(qsTr("Configuration warnings"), "configurationWarnings"),
                    tog(qsTr("Hide VRR buffer limit warnings"), "hideVrrBufferWarnings"), tog(qsTr("Discord Rich Presence"), "richPresence"),
                    { "type": "tog", "label": qsTr("Notify me about prerelease builds"),
                      "get": function() { return AutoUpdateChecker.notifyPrereleases },
                      "set": function(v) { AutoUpdateChecker.notifyPrereleases = v } } ] } ] },
            { "name": "Advanced", "title": qsTr("Advanced"), "panels": [
                { "title": qsTr("Decoding and network"), "rows": [
                    seg(qsTr("Video decoder"), "videoDecoderSelection", [qsTr("Auto"), qsTr("Software"), qsTr("Hardware")],
                        [P.VDS_AUTO, P.VDS_FORCE_SOFTWARE, P.VDS_FORCE_HARDWARE], true),
                    renderer,
                    tog(qsTr("Unlock bitrate limit"), "unlockBitrate"), tog(qsTr("Find PCs on this network"), "enableMdns"),
                    tog(qsTr("Detect blocked connections"), "detectNetworkBlocking") ] },
                { "title": qsTr("Overlay and VRR"), "rows": advancedRight } ] }
        ]
    }

    readonly property var languages: [
        [qsTr("Automatic"), StreamingPreferences.LANG_AUTO], ["Deutsch", StreamingPreferences.LANG_DE], ["English", StreamingPreferences.LANG_EN],
        ["Français", StreamingPreferences.LANG_FR], ["简体中文", StreamingPreferences.LANG_ZH_CN], ["Norwegian Bokmål", StreamingPreferences.LANG_NB_NO],
        ["русский", StreamingPreferences.LANG_RU], ["Español", StreamingPreferences.LANG_ES], ["日本語", StreamingPreferences.LANG_JA],
        ["Tiếng Việt", StreamingPreferences.LANG_VI], ["ภาษาไทย", StreamingPreferences.LANG_TH], ["한국어", StreamingPreferences.LANG_KO],
        ["Magyar", StreamingPreferences.LANG_HU], ["Nederlands", StreamingPreferences.LANG_NL], ["Svenska", StreamingPreferences.LANG_SV],
        ["Türkçe", StreamingPreferences.LANG_TR], ["Українська", StreamingPreferences.LANG_UK], ["繁體中文", StreamingPreferences.LANG_ZH_TW],
        ["Português", StreamingPreferences.LANG_PT], ["Português do Brasil", StreamingPreferences.LANG_PT_BR], ["Ελληνικά", StreamingPreferences.LANG_EL],
        ["Italiano", StreamingPreferences.LANG_IT], ["हिन्दी", StreamingPreferences.LANG_HI], ["Język polski", StreamingPreferences.LANG_PL],
        ["Čeština", StreamingPreferences.LANG_CS], ["עִבְרִית", StreamingPreferences.LANG_HE], ["کرمانجیی خواروو", StreamingPreferences.LANG_CKB],
        ["Lietuvių kalba", StreamingPreferences.LANG_LT], ["Eesti", StreamingPreferences.LANG_ET], ["Български", StreamingPreferences.LANG_BG],
        ["Esperanto", StreamingPreferences.LANG_EO], ["தமிழ்", StreamingPreferences.LANG_TA]
    ]
    function languageName(value) {
        for (var i = 0; i < languages.length; i++) {
            if (languages[i][1] === value) return languages[i][0]
        }
        return qsTr("Automatic")
    }
    Menu {
        id: languageMenu
        Repeater {
            model: settingsPage.languages
            delegate: MenuItem {
                text: modelData[0]
                onTriggered: {
                    StreamingPreferences.language = modelData[1]
                    StreamingPreferences.retranslate()
                }
            }
        }
    }

    // ---- Left column -------------------------------------------------------
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
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: window.showHosts() }
        }

        Column {
            anchors.top: namePill.bottom
            anchors.topMargin: 1.2 * cq
            x: 1.5 * cq
            width: parent.width - 3 * cq
            Repeater {
                model: settingsPage.tabList
                delegate: Item {
                    readonly property bool active: modelData.name === settingsPage.category
                    width: parent.width
                    height: 3.6 * settingsPage.cq
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.title
                        color: parent.active ? Theme.glassText : Theme.glassFaint
                        font.family: Theme.sansFont
                        font.weight: parent.active ? Font.Medium : Font.Normal
                        font.pixelSize: 1.9 * settingsPage.cq
                    }
                    // The one colour that stays when the PC is off
                    Rectangle {
                        visible: parent.active
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 0.9 * settingsPage.cq
                        height: width
                        radius: width / 2
                        color: Theme.glassOrange
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsPage.category = modelData.name }
                }
            }
        }

        Text {
            x: 1.5 * cq
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0.6 * cq
            text: "←  " + qsTr("Home")
            color: Theme.glassFaint
            font.family: Theme.sansFont
            font.pixelSize: 1.9 * cq
            MouseArea { anchors.fill: parent; anchors.margins: -0.6 * settingsPage.cq; cursorShape: Qt.PointingHandCursor; onClicked: window.showHosts() }
        }
    }

    // ---- The current category ----------------------------------------------
    Item {
        id: main
        x: 24.3 * cq
        y: 4.4 * cq
        width: parent.width - x - 1.8 * cq
        height: parent.height - y - 1.8 * cq
        readonly property real gap: 1.4 * settingsPage.cq

        FlutedGlass {
            id: strip
            width: parent.width
            height: 12.5 * settingsPage.cq
            radius: 2.2 * settingsPage.cq
            fluteWidth: 1.6 * settingsPage.cq
            variant: 2
            off: window.pcOff
            Column {
                x: 2.2 * settingsPage.cq
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1.6 * settingsPage.cq
                Text { text: qsTr("Settings"); color: Theme.glassText; font.family: Theme.sansFont; font.pixelSize: 1.6 * settingsPage.cq }
                Text {
                    text: settingsPage.current.title
                    color: Theme.glassText
                    font.family: Theme.sansFont
                    font.weight: Font.Medium
                    font.pixelSize: 3.9 * settingsPage.cq
                    font.letterSpacing: -0.03 * 3.9 * settingsPage.cq
                }
            }
        }

        Flickable {
            y: strip.height + main.gap
            width: parent.width
            height: parent.height - y
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: Math.max(height, panelRow.height)

            Row {
                id: panelRow
                spacing: main.gap
                Repeater {
                    model: settingsPage.current.panels
                    delegate: Rectangle {
                        width: (main.width - main.gap) / 2
                        height: Math.max(main.height - strip.height - main.gap, rows.height + 3 * settingsPage.cq)
                        radius: 2.2 * settingsPage.cq
                        color: Theme.glassPanel

                        Column {
                            id: rows
                            x: 2.1 * settingsPage.cq
                            y: 1.5 * settingsPage.cq
                            width: parent.width - 4.2 * settingsPage.cq
                            Text {
                                text: modelData.title
                                color: Theme.glassFaint
                                font.family: Theme.sansFont
                                font.pixelSize: 1.6 * settingsPage.cq
                                bottomPadding: 0.5 * settingsPage.cq
                            }
                            Repeater {
                                model: modelData.rows
                                delegate: settingsRow
                            }
                        }
                    }
                }
            }
        }
    }

    // One setting. Its control sits on the right of the label, or below it for wide choices.
    Component {
        id: settingsRow
        Column {
            id: rowItem
            readonly property var row: modelData
            readonly property real cq: settingsPage.cq
            readonly property bool below: (row.type === "seg" && row.wide) || row.type === "sld"
            readonly property bool tall: (row.type === "seg" && !row.wide) || row.type === "act" || row.type === "txt"
            width: parent ? parent.width : 0

            Rectangle { width: parent.width; height: 1; color: Theme.glassLine }
            Item {
                width: parent.width
                height: (rowItem.tall ? 6.3 : (rowItem.below ? 4.2 : 4.5)) * cq - 1

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: rowItem.below ? 0.15 * cq : 0
                    text: row.label
                    color: Theme.glassText
                    font.family: Theme.sansFont
                    font.pixelSize: 1.6 * cq
                }
                GlassToggle {
                    visible: row.type === "tog"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    cq: rowItem.cq
                    on: row.type === "tog" ? row.get() : false
                    onToggled: row.set(!row.get())
                }
                GlassSegments {
                    visible: row.type === "seg" && !row.wide
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    cq: rowItem.cq
                    options: visible ? row.options() : []
                    current: visible ? row.values().indexOf(row.get()) : -1
                    onPicked: function(i) { row.set(row.values()[i]) }
                }
                Text {
                    visible: row.type === "sld"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 0.15 * cq
                    text: qsTr("%1 Mbps").arg(Math.round(StreamingPreferences.bitrateKbps / 100) / 10)
                    color: Theme.glassText
                    font.family: Theme.sansFont
                    font.pixelSize: 1.6 * cq
                }
                // A button
                Rectangle {
                    visible: row.type === "act"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: actLabel.implicitWidth + 2.6 * cq
                    height: actLabel.implicitHeight + 1.5 * cq
                    radius: height / 2
                    color: "#FFFFFF"
                    border.width: 1
                    border.color: Theme.glassPillBorder
                    Text { id: actLabel; anchors.centerIn: parent; text: row.type === "act" ? row.text : ""; color: Theme.glassText; font.family: Theme.sansFont; font.pixelSize: 1.6 * cq }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.run() }
                }
                // A text field
                Rectangle {
                    visible: row.type === "txt"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16 * cq
                    height: 3.6 * cq
                    radius: height / 2
                    color: "#FFFFFF"
                    border.width: textField.activeFocus ? Math.max(1.5, 0.24 * cq) : 1
                    border.color: textField.activeFocus ? Theme.glassText : Theme.glassPillBorder
                    TextInput {
                        id: textField
                        anchors.fill: parent
                        anchors.leftMargin: 1.3 * cq
                        anchors.rightMargin: 1.3 * cq
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Theme.glassText
                        selectionColor: Theme.glassOrange
                        font.family: Theme.sansFont
                        font.pixelSize: 1.6 * cq
                        text: row.type === "txt" ? row.get() : ""
                        onEditingFinished: if (row.type === "txt") row.set(text.trim())
                    }
                }
            }

            // Wide choices, on their own line under the label
            GlassSegments {
                visible: row.type === "seg" && row.wide
                cq: rowItem.cq
                options: visible ? row.options() : []
                current: visible ? row.values().indexOf(row.get()) : -1
                onPicked: function(i) { row.set(row.values()[i]) }
            }
            // A custom size, typed as width x height, when Custom is the current choice
            Rectangle {
                id: customSize
                visible: row.custom === true && row.get() === 3
                width: 16 * cq
                height: visible ? 3.6 * cq : 0
                radius: height / 2
                color: "#FFFFFF"
                border.width: sizeField.activeFocus ? Math.max(1.5, 0.24 * cq) : 1
                border.color: sizeField.activeFocus ? Theme.glassText : Theme.glassPillBorder
                TextInput {
                    id: sizeField
                    anchors.fill: parent
                    anchors.leftMargin: 1.3 * cq
                    anchors.rightMargin: 1.3 * cq
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: Theme.glassText
                    selectionColor: Theme.glassOrange
                    font.family: Theme.sansFont
                    font.pixelSize: 1.6 * cq
                    text: StreamingPreferences.width + " × " + StreamingPreferences.height
                    onEditingFinished: {
                        var m = text.match(/(\d{3,5})\D+(\d{3,5})/)
                        // Sizes must be even for the video encoder
                        if (m) settingsPage.setSize(m[1] - m[1] % 2, m[2] - m[2] % 2)
                        text = Qt.binding(function() { return StreamingPreferences.width + " × " + StreamingPreferences.height })
                    }
                }
            }
            Item { visible: customSize.visible; width: 1; height: 0.8 * cq }
            Item { visible: row.type === "seg" && row.wide; width: 1; height: 1.3 * cq }

            // The bitrate slider
            Item {
                id: slider
                visible: row.type === "sld"
                width: parent.width
                height: visible ? 1.9 * cq : 0
                readonly property int from: 500
                readonly property int to: StreamingPreferences.unlockBitrate ? 500000 : 150000
                readonly property real position: Math.max(0, Math.min(1, (StreamingPreferences.bitrateKbps - from) / (to - from)))
                function moveTo(x) {
                    var kbps = from + Math.max(0, Math.min(1, x / width)) * (to - from)
                    StreamingPreferences.bitrateKbps = Math.max(from, Math.round(kbps / 500) * 500)
                    // Chosen by hand: it no longer follows the resolution
                    StreamingPreferences.autoAdjustBitrate = false
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 0.5 * cq
                    radius: height / 2
                    color: Theme.glassLine
                    Rectangle {
                        width: parent.width * slider.position
                        height: parent.height
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.glassOrange }
                            GradientStop { position: 1; color: Theme.glassSage }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            opacity: window.pcOff ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 500 } }
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: "#878787" }
                                GradientStop { position: 1; color: "#C3C3C3" }
                            }
                        }
                    }
                }
                Rectangle {
                    x: slider.position * slider.width - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1.7 * cq
                    height: width
                    radius: width / 2
                    color: "#FFFFFF"
                    border.width: Math.max(1.5, 0.24 * cq)
                    border.color: Theme.glassText
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -0.6 * cq
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(mouse) { slider.moveTo(mouse.x - 0.6 * cq) }
                    onPositionChanged: function(mouse) { if (pressed) slider.moveTo(mouse.x - 0.6 * cq) }
                }
            }
            Item { visible: row.type === "sld"; width: 1; height: 1.1 * cq }
        }
    }
}
