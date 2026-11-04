// DeckVoid theme, following the design kit in docs/design/KIT.md.
pragma Singleton
import QtQuick
import InputMode 1.0

QtObject {
    // "controller" | "mouse" | "touch": follows the last input used (InputMode).
    readonly property string inputMode: InputMode.mode
    readonly property bool controllerMode: inputMode === "controller"
    readonly property bool mouseMode: inputMode === "mouse"
    readonly property bool touchMode: inputMode === "touch"

    // Kit colours (docs/design/KIT.md). Paper is the main surface; ink is text;
    // vermilion is the main action; marigold marks "running"; moss is the PC block.
    readonly property color paper: "#F1EEE9"
    readonly property color bone: "#FAF9F6"
    readonly property color ash: "#EAE9E8"
    readonly property color ink: "#111111"
    readonly property color soot: "#282625"
    readonly property color stone: "#6E6965"
    readonly property color vermilion: "#E05D4E"
    readonly property color marigold: "#F4C33F"
    readonly property color cobalt: "#3B6FD6"
    readonly property color moss: "#5F733C"
    readonly property color olive: "#454539"
    readonly property color rule: Qt.rgba(17/255, 17/255, 17/255, 0.18)
    readonly property color cardRule: Qt.rgba(17/255, 17/255, 17/255, 0.25)

    // Older role names, mapped onto the kit so every existing screen follows it.
    readonly property color background: paper
    readonly property color surface: bone
    readonly property color surfaceMuted: ash
    readonly property color line: "#D6D2CB"
    readonly property color lineStrong: "#BDB7AE"
    readonly property color dashed: "#BDB7AE"
    readonly property color chip: ash
    readonly property color bumper: "#E2DFDA"
    readonly property color text: ink
    readonly property color textStrong: ink
    readonly property color textSecondary: "#3A3734"
    readonly property color textMuted: stone
    readonly property color textFaint: "#8A857F"
    readonly property color accent: vermilion
    readonly property color accentText: bone   // text on an accent fill
    readonly property color accentTint: "#F6DAD5"
    readonly property color accentDeep: "#B8463A"
    readonly property color secondary: moss
    readonly property color secondaryTint: Qt.rgba(95/255, 115/255, 60/255, 0.18)
    readonly property color statusReady: moss
    readonly property color statusNeedsPairing: vermilion
    readonly property color statusAsleep: "#C9C4BC"
    readonly property color glyphFill: ink
    readonly property color glyphText: bone
    readonly property color scrim: Qt.rgba(17/255, 17/255, 17/255, 0.40)
    readonly property color shadow: "transparent"   // the kit has no shadows
    readonly property color glow: "transparent"

    // Type: IBM Plex Sans for everything, IBM Plex Mono for facts (addresses,
    // versions, labels, controller hints). Controller sizes; mouse x0.86, touch x0.96.
    readonly property FontLoader plexSansLoader: FontLoader { source: "qrc:/res/fonts/IBMPlexSans.ttf" }
    readonly property FontLoader plexMonoLoader: FontLoader { source: "qrc:/res/fonts/IBMPlexMono-Regular.ttf" }
    readonly property FontLoader plexMonoMediumLoader: FontLoader { source: "qrc:/res/fonts/IBMPlexMono-Medium.ttf" }
    readonly property string sansFont: plexSansLoader.status === FontLoader.Ready ? plexSansLoader.name : "sans-serif"
    readonly property string monoFont: plexMonoLoader.status === FontLoader.Ready ? plexMonoLoader.name : "monospace"
    readonly property string headingFont: sansFont
    readonly property string bodyFont: sansFont
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
    // The kit allows 4 px at most, on buttons and cards only.
    readonly property int radiusCard: 4
    readonly property int radiusDialog: 4
    readonly property int radiusControl: 4
    readonly property int headerHeight: 64
    readonly property int footerHeight: 44
    readonly property int minHitTarget: mouseMode ? 28 : 44
    readonly property int pageGutter: controllerMode ? 40 : 32
    readonly property int gridGap: 20
    readonly property int cardPadding: 18
    readonly property int statusStrip: 7
    readonly property int statusDot: 11
}
