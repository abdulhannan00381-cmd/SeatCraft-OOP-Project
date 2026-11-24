import QtQuick

// One seat: cushion, backrest and — for VIP — armrests.
// States: available, selected, booked. Drawn at 40 x 38 and scaled.
Item {
    id: root
    property bool vip: false
    property string seatState: "available"     // available | selected | booked
    property int number: 0
    property bool inspected: false
    property bool interactive: true
    property string label: ""
    signal picked()
    signal looked()

    width: 40; height: 38
    activeFocusOnTab: interactive
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.checkable: true
    Accessible.checked: seatState === "selected"
    Keys.onReturnPressed: picked()
    Keys.onSpacePressed: picked()
    onActiveFocusChanged: if (activeFocus) looked()

    readonly property real k: width / 40
    readonly property bool sel: seatState === "selected"
    readonly property bool taken: seatState === "booked"
    readonly property bool hot: hover.hovered && interactive && !taken

    Item {
        id: body
        width: 40; height: 38
        scale: root.k
        transformOrigin: Item.TopLeft

        Rectangle { visible: root.vip; x: 0.5; y: 8; width: 5; height: 22; radius: 2.5
                    color: root.sel ? Theme.amberDeep : root.taken ? "#2C2924" : "#7A6A4C" }
        Rectangle { visible: root.vip; x: 34.5; y: 8; width: 5; height: 22; radius: 2.5
                    color: root.sel ? Theme.amberDeep : root.taken ? "#2C2924" : "#7A6A4C" }
        Rectangle { x: 5; y: 28; width: 30; height: 7; radius: 3.5
                    color: root.sel ? Theme.amberDeep : root.taken ? "#2C2924" : root.vip ? "#8C7A55" : "#5A544B" }
        Rectangle {
            id: cushion
            x: 7; y: 3; width: 26; height: 23; radius: 6
            color: root.sel ? Theme.amber
                 : root.taken ? "#211E1A"
                 : root.hot ? (root.vip ? Qt.rgba(233 / 255, 217 / 255, 184 / 255, 0.28) : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.18))
                 : root.vip ? Qt.rgba(233 / 255, 217 / 255, 184 / 255, 0.10) : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.05)
            border.width: root.inspected ? 2.4 : 1.4
            border.color: root.sel ? Theme.amber : root.taken ? "#3A362F" : root.vip ? Theme.vip : "#CFC7B9"
            Behavior on color { ColorAnimation { duration: Theme.quick } }

            Text {
                anchors.centerIn: parent
                visible: !root.taken && root.number > 0
                text: root.number
                font.family: Theme.mono; font.pixelSize: 10
                color: root.sel ? "#1A1206" : Theme.ink
            }
            Rectangle {      // diagonal slash on taken seats
                visible: root.taken
                anchors.centerIn: parent
                width: 24; height: 1.6
                rotation: -40
                color: "#6F695F"
            }
        }
        Rectangle {          // soft glow behind a selected seat
            z: -1
            visible: root.sel
            anchors.centerIn: cushion
            width: 40; height: 36; radius: 12
            color: Qt.rgba(245 / 255, 181 / 255, 68 / 255, 0.28)
        }
    }

    Rectangle {
        anchors.fill: parent; anchors.margins: -3
        color: "transparent"; radius: 6
        border.color: Theme.ink; border.width: 2
        visible: root.activeFocus
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: cushion; property: "scale"; from: 0.82; to: 1.14; duration: 210; easing.type: Easing.OutCubic }
        NumberAnimation { target: cushion; property: "scale"; to: 1.0; duration: 140; easing.type: Easing.OutBack }
    }
    onSeatStateChanged: if (seatState === "selected") popAnim.restart()

    HoverHandler {
        id: hover
        enabled: root.interactive
        cursorShape: root.taken ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        onHoveredChanged: if (hovered) root.looked()
    }
    TapHandler { enabled: root.interactive; onTapped: root.picked() }
}
