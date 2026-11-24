import QtQuick
import QtQuick.Layouts

// Shown when the data file is damaged. The file is never overwritten silently.
Rectangle {
    id: root
    color: Theme.bg
    property string result: ""

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(720, parent.width - 2 * Theme.gutter)
        spacing: 18
        Text { text: "WE COULDN'T OPEN YOUR BOOKINGS"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 52; color: Theme.ink; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: app.loadError; font.family: Theme.mono; font.pixelSize: 13; color: "#FFC2BB" }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
               text: "Nothing has been changed. You can close SeatCraft and restore a backup, or start again with the sample programme — the damaged file will be kept beside it for inspection."
               font.family: Theme.body; font.pixelSize: 16; lineHeight: 1.3; color: Theme.ink2 }
        RowLayout {
            spacing: 12
            AppButton { kind: "primary"; text: "Start again with the sample programme"; onClicked: root.result = app.restoreSampleData().message }
            AppButton { kind: "secondary"; text: "Close SeatCraft"; onClicked: Qt.quit() }
        }
        Text { visible: root.result !== ""; text: root.result; font.family: Theme.body; font.pixelSize: 14; color: Theme.muted }
    }
}
