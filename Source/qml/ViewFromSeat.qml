import QtQuick
import QtQuick.Shapes

// Approximate view of the stage from one seat: the stage shrinks with
// distance, skews with the seat's angle, and rows in front appear as heads.
Column {
    id: root
    property string eventId
    property string seatId
    readonly property var v: (app.revision, seatId ? app.viewFromSeat(eventId, seatId) : ({}))
    spacing: 8

    Rectangle {
        width: root.width; height: width * 150 / 360
        radius: Theme.radius; clip: true
        color: "#050506"
        border.color: Theme.line
        Accessible.role: Accessible.Graphic
        Accessible.name: "Approximate view of the stage from seat " + root.seatId

        Item {
            width: 360; height: 150
            scale: parent.width / 360
            transformOrigin: Item.TopLeft
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: 150
                        GradientStop { position: 0; color: "#14162E" }
                        GradientStop { position: 1; color: "#050506" }
                    }
                    PathSvg { path: "M0 0 L360 0 L360 150 L0 150 Z" }
                }
                ShapePath { strokeWidth: -1; fillColor: "#1A1C3A"; PathSvg { path: root.v.floor || "" } }
                ShapePath {
                    strokeColor: Qt.rgba(201 / 255, 210 / 255, 1, 0.6); strokeWidth: 1
                    fillColor: Theme.stageFill
                    PathSvg { path: root.v.stage || "" }
                }
                ShapePath { strokeWidth: -1; fillColor: "#030304"; fillRule: ShapePath.WindingFill; PathSvg { path: root.v.heads || "" } }
            }
            Rectangle {
                visible: root.v.speakerR !== undefined
                x: (root.v.speakerX || 0) - (root.v.speakerR || 0); y: (root.v.speakerY || 0) - (root.v.speakerR || 0)
                width: (root.v.speakerR || 0) * 2; height: width; radius: width / 2
                color: "#050506"
            }
        }
        Text {
            x: 10; y: 8
            text: "VIEW FROM " + root.seatId
            font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.2
            color: Theme.stageEdge
        }
    }
    Text {
        width: root.width
        text: root.v.caption || ""
        wrapMode: Text.WordWrap
        font.family: Theme.mono; font.pixelSize: 11
        color: Theme.muted
    }
}
