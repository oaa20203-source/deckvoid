import QtQuick
import QtQuick.Window

// A panel of fluted glass with soft colours drifting behind it
// (design/mockups/home-glass.html). Drawn by shaders/fluted.frag.
ShaderEffect {
    id: glass

    // 0 hero, 1 app tile, 2 settings strip, 3 pairing page: which colours and where
    property real variant: 0
    // Offsets the motion so two panels do not move together
    property real seed: 0
    // 0 = colour, 1 = greyscale. Set `off` rather than this to fade between them.
    property real grey: off ? 1 : 0
    property bool off: false
    // Corner radius and flute width in logical pixels
    property real radius: 0
    property real fluteWidth: 12
    property bool running: true

    // Uniforms
    property real time: 0
    readonly property real dpr: Screen.devicePixelRatio
    readonly property real flutePx: Math.max(4, Math.round(fluteWidth * dpr))
    readonly property real radiusPx: radius * dpr
    readonly property size pixelSize: Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr))

    fragmentShader: "qrc:/gui/shaders/fluted.frag.qsb"

    Behavior on grey { NumberAnimation { duration: 500 } }

    // The speed chosen in the mockup: 62 on its slider, 2.48 units a second
    FrameAnimation {
        running: glass.running && glass.visible
        onTriggered: glass.time += Math.min(frameTime, 0.1) * 2.48
    }
}
