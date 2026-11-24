import QtQuick
import QtQuick.Controls.Basic

// Buttons in four looks: primary (amber), secondary (outline),
// outlineAmber and danger.
Button {
    id: root
    property string kind: "secondary"
    property int textSize: 15

    implicitHeight: 50
    leftPadding: 24; rightPadding: 24
    hoverEnabled: true
    Accessible.name: text

    readonly property color fillColor: kind === "primary" ? (hovered ? "#FFC864" : Theme.amber)
                                     : kind === "danger" ? Theme.danger
                                     : kind === "outlineAmber" && hovered ? Theme.amber
                                     : "transparent"
    readonly property color textColor: kind === "primary" ? "#1A1206"
                                     : kind === "danger" ? "#2A0703"
                                     : kind === "outlineAmber" ? (hovered ? "#1A1206" : Theme.amber)
                                     : Theme.ink

    contentItem: Text {
        text: root.text
        font.family: Theme.body
        font.pixelSize: root.textSize
        font.weight: Font.Bold
        color: root.enabled ? root.textColor : Theme.dim
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Theme.radius
        color: root.fillColor
        border.width: root.kind === "primary" || root.kind === "danger" ? 0 : 1
        border.color: root.kind === "outlineAmber" ? Theme.amber
                    : root.hovered ? Theme.ink : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.3)
        Rectangle {
            anchors.fill: parent; anchors.margins: -4
            radius: Theme.radius + 2
            color: "transparent"
            border.color: Theme.amber; border.width: 2
            visible: root.visualFocus
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
