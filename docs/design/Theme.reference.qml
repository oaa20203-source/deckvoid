// Reference only: a starting point for a QML theme singleton built from tokens.json.
// Not registered or imported anywhere yet. To use it, add `pragma Singleton` handling
// via a qmldir entry (or qmlRegisterSingletonType in main.cpp) and replace hard-coded
// colours in app/gui/*.qml with Theme.<name>.
pragma Singleton
import QtQuick 2.15

QtObject {
    // "controller" | "mouse" | "touch". Driven by the last input used (see DESIGN.md, Input modes).
    property string inputMode: "controller"
    readonly property bool controllerMode: inputMode === "controller"
    readonly property bool mouseMode: inputMode === "mouse"
    readonly property bool touchMode: inputMode === "touch"

    // Colours
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
    readonly property color scrim: Qt.rgba(60/255, 45/255, 30/255, 0.38)

    // Type
    readonly property string headingFont: "Urbanist"
    readonly property string bodyFont: "Quicksand"
    readonly property real typeScale: mouseMode ? 0.86 : (touchMode ? 0.96 : 1.0)
    function px(size) { return Math.round(size * typeScale) }

    // Shape
    readonly property int radiusCard: 26
    readonly property int radiusDialog: 30
    readonly property int radiusControl: mouseMode ? 8 : 22
    readonly property int minHitTarget: mouseMode ? 28 : 44
}
