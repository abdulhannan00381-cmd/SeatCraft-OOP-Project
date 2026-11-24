import QtQuick

// Text link in the top bar with an amber underline when active.
Item {
    id: root
    property string text
    property bool active: false
    signal clicked()

    implicitWidth: label.implicitWidth + 8
    implicitHeight: 44
    activeFocusOnTab: true
    Accessible.role: Accessible.Link
    Accessible.name: text
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.body
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: root.active || hover.hovered ? Theme.ink : "#C9C2B6"
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 2
        color: root.active ? Theme.amber : "transparent"
    }
    Rectangle {
        anchors.fill: parent; anchors.margins: -3
        color: "transparent"; radius: 3
        border.color: Theme.amber; border.width: 2
        visible: root.activeFocus
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.clicked() }
}
