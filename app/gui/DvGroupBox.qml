// A settings group (docs/design/KIT.md): no box, just a bold heading over a
// 1 px ink rule, shown only when its section is selected in the Settings blocks.
import QtQuick
import QtQuick.Controls
import DeckVoidTheme 1.0

GroupBox {
    id: box
    // "video" | "input" | "audio" | "host"
    property string category: "video"
    property string selectedCategory: "video"

    visible: category === selectedCategory
    width: parent ? parent.width - (parent.leftPadding + parent.rightPadding) : implicitWidth
    padding: 0
    leftPadding: 0
    rightPadding: 0
    bottomPadding: 18
    topPadding: label.implicitHeight + 22
    font.pointSize: 12

    background: Item {
        Rectangle {
            y: box.label.implicitHeight + 10
            width: box.width
            height: 1
            color: Theme.ink
        }
    }

    label: Text {
        x: 0
        width: box.availableWidth
        text: box.title
        color: Theme.ink
        font.family: Theme.sansFont
        font.weight: Font.Bold
        font.pixelSize: 24
        font.letterSpacing: -0.5
        elide: Text.ElideRight
    }
}
