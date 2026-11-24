import QtQuick
import QtQuick.Layouts

// Wordmark, main navigation and the desk label.
Rectangle {
    id: root
    property string current: "discover"
    signal navigate(string page)

    height: 88
    color: Theme.bg

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.gutter; anchors.rightMargin: Theme.gutter
        spacing: 44

        Row {
            Text { text: "SEAT"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 26; font.letterSpacing: 3.5; color: Theme.ink }
            Text { text: "CRAFT"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 26; font.letterSpacing: 3.5; color: Theme.amber }
            Accessible.role: Accessible.StaticText
            Accessible.name: "SeatCraft"
        }
        Row {
            spacing: 28
            NavLink { text: "Discover"; active: root.current === "discover" || root.current === "seats"; onClicked: root.navigate("discover") }
            NavLink { text: "Bookings"; active: root.current === "bookings"; onClicked: root.navigate("bookings") }
            NavLink { text: "Venues"; active: root.current === "venues"; onClicked: root.navigate("venues") }
            NavLink { text: "Organizer"; active: root.current === "organizer"; onClicked: root.navigate("organizer") }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: "Box office · Desk 01"
            font.family: Theme.mono; font.pixelSize: 12
            color: "#C9C2B6"
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
}
