// A settings group: a white card with rounded corners and a heading, shown only
// when its category is the one selected in the Settings sidebar.
import QtQuick
import QtQuick.Controls
import DeckVoidTheme 1.0

GroupBox {
    id: box
    // "stream" | "host" | "controls" | "haptics" | "overlay" | "about"
    property string category: "stream"
    property string selectedCategory: "stream"

    visible: category === selectedCategory
    width: parent ? parent.width - (parent.leftPadding + parent.rightPadding) : implicitWidth
    padding: 22
    topPadding: label.implicitHeight + 34
    font.pointSize: 12

    background: Rectangle {
        y: box.label.implicitHeight + 12
        width: box.width
        height: box.height - y
        radius: Theme.radiusCard
        color: Theme.surface
        border.color: Theme.line
        border.width: 1
    }

    label: Text {
        x: 4
        width: box.availableWidth
        text: box.title
        color: Theme.text
        font.family: Theme.headingFont
        font.weight: Font.Bold
        font.pixelSize: Theme.px(22)
        elide: Text.ElideRight
    }
}
