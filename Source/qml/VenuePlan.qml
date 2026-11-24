import QtQuick
import QtQuick.Shapes

// Seat plan for any venue layout (fan, flat, tiered). Geometry comes from
// the C++ Venue class; this item only draws it and reports clicks.
//   mode "seats"   — real seats with booked/selected states (eventId required)
//   mode "zones"   — VIP/Regular zones only
//   mode "locator" — small dots, highlighting `highlight` seats
Item {
    id: root
    property string venueId
    property string eventId
    property string mode: "seats"
    property var selected: []
    property var highlight: []
    property bool dimHighlight: false
    property string inspected: ""
    property bool interactive: true
    property string vipText: "VIP"
    property string regularText: "REGULAR"
    property string vipPriceText: ""
    property string regularPriceText: ""
    signal seatPicked(string seatId)
    signal seatLooked(string seatId)

    readonly property var plan: (app.revision, app.venuePlan(venueId, mode === "zones" ? "" : eventId))
    readonly property real s: Math.min(width / 920, height / 470)

    implicitWidth: 920
    implicitHeight: 470

    Item {
        id: canvas
        width: 920; height: 470
        scale: root.s
        transformOrigin: Item.TopLeft
        x: (root.width - 920 * root.s) / 2

        Shape {
            anchors.fill: parent
            ShapePath {     // stage light
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: 460; centerY: 70; centerRadius: 440; focalX: 460; focalY: 70
                    GradientStop { position: 0; color: Qt.rgba(228 / 255, 232 / 255, 1, 0.13) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathSvg { path: "M0 0 L920 0 L920 470 L0 470 Z" }
            }
            ShapePath {
                strokeColor: Qt.rgba(233 / 255, 217 / 255, 184 / 255, 0.25)
                strokeWidth: 1; strokeStyle: ShapePath.DashLine; dashPattern: [3, 5]
                fillColor: Qt.rgba(233 / 255, 217 / 255, 184 / 255, 0.05)
                PathSvg { path: root.plan.vipPlate || "" }
            }
            ShapePath {
                strokeColor: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.12)
                strokeWidth: 1; strokeStyle: ShapePath.DashLine; dashPattern: [3, 5]
                fillColor: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.025)
                PathSvg { path: root.plan.regularPlate || "" }
            }
            ShapePath {
                strokeColor: Qt.rgba(201 / 255, 210 / 255, 1, 0.6)
                strokeWidth: 1.5
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: 100
                    GradientStop { position: 0; color: "#2A2D52" }
                    GradientStop { position: 1; color: "#14152A" }
                }
                PathSvg { path: root.plan.stage || "" }
            }
        }

        Text {
            x: 0; width: 920; y: (root.plan.stageLabelY || 50) - 10
            horizontalAlignment: Text.AlignHCenter
            text: "S T A G E"
            font.family: Theme.mono; font.pixelSize: 13; font.letterSpacing: 4
            color: "#E4E8FF"
        }
        Text {
            visible: root.mode !== "locator"
            x: 0; width: 920; y: (root.plan.vipLabelY || 110) - 8
            horizontalAlignment: Text.AlignHCenter
            text: root.vipText + (root.vipPriceText ? " · " + root.vipPriceText : "")
            font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 3
            color: Theme.vip
        }
        Text {
            visible: root.mode !== "locator"
            x: 0; width: 920; y: (root.plan.regularLabelY || 410) - 8
            horizontalAlignment: Text.AlignHCenter
            text: root.regularText + (root.regularPriceText ? " · " + root.regularPriceText : "")
            font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 3
            color: "#C9C2B6"
        }
        Repeater {
            model: root.mode === "locator" ? [] : [root.plan.exitLeft, root.plan.exitRight]
            Rectangle {
                x: modelData || 0; y: root.plan.exitY || 0
                width: 34; height: 26; color: "transparent"
                border.color: Qt.rgba(127 / 255, 214 / 255, 164 / 255, 0.75)
                Text { anchors.centerIn: parent; text: "EXIT"; font.family: Theme.mono; font.pixelSize: 9; color: Theme.ok }
            }
        }
        Repeater {
            model: root.plan.labels || []
            Text {
                x: modelData.x - 12; y: modelData.y - 10; width: 24
                horizontalAlignment: Text.AlignHCenter
                text: modelData.text
                font.family: Theme.mono; font.pixelSize: 13
                color: Theme.muted
            }
        }

        Repeater {
            model: root.plan.seats || []
            delegate: Item {
                id: slot
                required property var modelData
                readonly property bool isSel: root.selected.indexOf(modelData.id) >= 0
                readonly property bool isHi: root.highlight.indexOf(modelData.id) >= 0
                x: modelData.x; y: modelData.y
                width: modelData.w; height: modelData.h
                rotation: modelData.rotation

                SeatGlyph {
                    visible: root.mode !== "locator"
                    anchors.fill: parent
                    vip: slot.modelData.vip
                    number: slot.modelData.number
                    seatState: slot.modelData.booked ? "booked" : slot.isSel ? "selected" : "available"
                    inspected: root.inspected === slot.modelData.id
                    interactive: root.interactive
                    label: "Row " + slot.modelData.row + " seat " + slot.modelData.number + ", "
                           + (slot.modelData.vip ? "VIP" : "Regular")
                           + (root.vipPriceText ? ", " + (slot.modelData.vip ? root.vipPriceText : root.regularPriceText) : "")
                           + ", " + (slot.modelData.booked ? "taken" : slot.isSel ? "selected" : "available")
                    onPicked: root.seatPicked(slot.modelData.id)
                    onLooked: root.seatLooked(slot.modelData.id)
                }
                Rectangle {
                    visible: root.mode === "locator"
                    anchors.centerIn: parent
                    width: parent.width * 0.62; height: parent.height * 0.62; radius: 4
                    color: slot.isHi ? (root.dimHighlight ? "#6F695F" : Theme.amber)
                         : slot.modelData.vip ? Qt.rgba(233 / 255, 217 / 255, 184 / 255, 0.45)
                         : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.22)
                }
            }
        }
    }
}
