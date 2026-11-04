// DeckVoid light theme. Values come from docs/design/tokens.json; see docs/design/DESIGN.md.
pragma Singleton
import QtQuick 2.15
import InputMode 1.0

QtObject {
    // "controller" | "mouse" | "touch": follows the last input used (InputMode).
    readonly property string inputMode: InputMode.mode
    readonly property bool controllerMode: inputMode === "controller"
    readonly property bool mouseMode: inputMode === "mouse"
    readonly property bool touchMode: inputMode === "touch"

    // Colours. Accent, secondary and status colours are fills, edges, dots and rings
    // only: they are too light to read as text on white.
    readonly property color background: "#FFFFFF"
    readonly property color surface: "#FFFFFF"
    readonly property color surfaceMuted: "#FAF8F5"
    readonly property color line: "#EEEAE4"
    readonly property color lineStrong: "#E6DFD4"
    readonly property color dashed: "#E2D6C2"
    readonly property color chip: "#F3EFE8"
    readonly property color bumper: "#F1EADD"
    readonly property color text: "#2A2420"
    readonly property color textStrong: "#3E352F"
    readonly property color textSecondary: "#5A4E45"
    readonly property color textMuted: "#6B5F55"
    readonly property color textFaint: "#8A7D70"
    readonly property color accent: "#F7B267"
    readonly property color accentTint: "#FEF0DE"
    readonly property color accentDeep: "#B36A1C"
    readonly property color secondary: "#D7A6D9"
    readonly property color secondaryTint: Qt.rgba(215/255, 166/255, 217/255, 0.28)
    readonly property color statusReady: "#9FD3A8"
    readonly property color statusNeedsPairing: "#F7B267"
    readonly property color statusAsleep: "#DDD3C3"
    readonly property color glyphFill: "#2A2420"
    readonly property color glyphText: "#FFFFFF"
    readonly property color scrim: Qt.rgba(60/255, 45/255, 30/255, 0.38)
    readonly property color shadow: Qt.rgba(90/255, 60/255, 30/255, 0.22)
    readonly property color glow: Qt.rgba(247/255, 178/255, 103/255, 0.20)

    // Type: controller sizes; mouse x0.86, touch x0.96.
    readonly property FontLoader urbanistLoader: FontLoader { source: "qrc:/res/fonts/Urbanist.ttf" }
    readonly property FontLoader quicksandLoader: FontLoader { source: "qrc:/res/fonts/Quicksand.ttf" }
    readonly property string headingFont: urbanistLoader.status === FontLoader.Ready ? urbanistLoader.name : "sans-serif"
    readonly property string bodyFont: quicksandLoader.status === FontLoader.Ready ? quicksandLoader.name : "sans-serif"
    readonly property real typeScale: mouseMode ? 0.86 : (touchMode ? 0.96 : 1.0)
    function px(size) { return Math.round(size * typeScale) }

    readonly property int pageTitle: px(34)
    readonly property int dialogTitle: px(30)
    readonly property int settingsTitle: px(30)
    readonly property int cardTitle: px(23)
    readonly property int tab: px(21)
    readonly property int row: px(19)
    readonly property int body: px(17)
    readonly property int meta: px(15)
    readonly property int label: px(14)
    readonly property real labelTracking: 0.6

    // Shape and spacing
    readonly property int radiusCard: 26
    readonly property int radiusDialog: 30
    readonly property int radiusControl: mouseMode ? 8 : 22
    readonly property int minHitTarget: mouseMode ? 28 : 44
    readonly property int pageGutter: controllerMode ? 40 : 32
    readonly property int gridGap: 20
    readonly property int cardPadding: 18
    readonly property int statusStrip: 7
    readonly property int statusDot: 11
}
