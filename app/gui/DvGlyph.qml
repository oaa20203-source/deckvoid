// Controller button glyph for footer hints: a dark circle with a letter, or a
// rounded square for symbols such as ≡ and the L1/R1 bumpers.
import QtQuick
import DeckVoidTheme 1.0

Rectangle {
    property string glyph: "A"
    property bool bumper: glyph === "L1" || glyph === "R1"
    readonly property bool dpad: glyph === "‹›"
    readonly property bool square: bumper || dpad || glyph === "≡"

    implicitWidth: dpad ? 60 : (bumper ? 44 : (square ? 44 : 40))
    implicitHeight: bumper ? 32 : 40
    radius: bumper ? 8 : (square ? 8 : height / 2)
    color: bumper ? Theme.bumper : Theme.glyphFill

    Text {
        anchors.centerIn: parent
        text: parent.dpad ? "◀▶" : parent.glyph
        color: parent.bumper ? Theme.textSecondary : Theme.glyphText
        font.family: Theme.bodyFont
        font.weight: Font.Bold
        font.pixelSize: parent.bumper ? 14 : (parent.dpad ? 15 : 19)
    }
}
