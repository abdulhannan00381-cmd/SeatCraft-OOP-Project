import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Adds a draft event. The schedule rules (and conflict check) run in C++.
Popup {
    id: root
    signal created(string eventId, string date, string message, bool hasConflict)

    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: 560
    padding: 32
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property string error: ""

    function openFor(date) {
        title.text = ""; dateField.text = date; start.text = "18:00"; end.text = "20:00"
        vip.text = "1000"; regular.text = "600"; category.currentIndex = 0; venue.currentIndex = 0
        error = ""
        open()
        title.forceActiveFocus()
    }
    function submit() {
        const v = app.venues[venue.currentIndex]
        const r = app.createEvent({ title: title.text, category: category.currentText, date: dateField.text,
                                    start: start.text, end: end.text, venueId: v.id,
                                    vipPrice: parseInt(vip.text) || 0, regularPrice: parseInt(regular.text) || 0 })
        if (!r.ok) { error = r.message; return }
        created(r.eventId, dateField.text, r.message, r.hasConflict)
        close()
    }

    background: Rectangle { color: Theme.surface; radius: 8; border.color: Theme.line }
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.6) }

    component Field: TextField {
        id: f
        implicitHeight: 46
        color: Theme.ink; font.family: Theme.body; font.pixelSize: 15
        leftPadding: 14
        placeholderTextColor: Theme.dim
        background: Rectangle { radius: Theme.radius; color: Theme.bg
                                border.color: f.activeFocus ? Theme.amber : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.25)
                                border.width: f.activeFocus ? 2 : 1 }
    }
    component Label2: Text { font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: Theme.muted }
    component Choice: ComboBox {
        id: cb
        implicitHeight: 46
        font.family: Theme.body; font.pixelSize: 15
        contentItem: Text { leftPadding: 14; text: cb.displayText; font: cb.font; color: Theme.ink; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: Theme.radius; color: Theme.bg
                                border.color: cb.activeFocus ? Theme.amber : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.25)
                                border.width: cb.activeFocus ? 2 : 1 }
    }

    contentItem: ColumnLayout {
        spacing: 14
        Text { text: "NEW EVENT"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 40; color: Theme.ink }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "New events start as drafts. Publish them from the Organizer once the schedule is clear."
               font.family: Theme.body; font.pixelSize: 14; color: Theme.muted }

        Label2 { text: "TITLE" }
        Field { id: title; Layout.fillWidth: true; placeholderText: "Event title"; Accessible.name: "Event title" }

        GridLayout {
            Layout.fillWidth: true
            columns: 2; columnSpacing: 14; rowSpacing: 8
            Label2 { text: "CATEGORY" }
            Label2 { text: "VENUE" }
            Choice { id: category; Layout.fillWidth: true; model: ["Talks", "Music", "Tech", "Theatre", "Sports", "Film", "Festival", "Art"]; Accessible.name: "Category" }
            Choice { id: venue; Layout.fillWidth: true; model: app.venues.map((v) => v.name); Accessible.name: "Venue" }
            Label2 { text: "DATE (YYYY-MM-DD)" }
            Label2 { text: "START – END" }
            Field { id: dateField; Layout.fillWidth: true; Accessible.name: "Date" }
            RowLayout {
                Layout.fillWidth: true
                Field { id: start; Layout.fillWidth: true; Accessible.name: "Start time" }
                Text { text: "–"; color: Theme.muted; font.pixelSize: 16 }
                Field { id: end; Layout.fillWidth: true; Accessible.name: "End time" }
            }
            Label2 { text: "VIP PRICE (Rs)" }
            Label2 { text: "REGULAR PRICE (Rs)" }
            Field { id: vip; Layout.fillWidth: true; inputMethodHints: Qt.ImhDigitsOnly; Accessible.name: "VIP price" }
            Field { id: regular; Layout.fillWidth: true; inputMethodHints: Qt.ImhDigitsOnly; Accessible.name: "Regular price" }
        }

        Text { visible: root.error !== ""; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.error; font.family: Theme.body; font.pixelSize: 14; color: "#FFC2BB" }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Item { Layout.fillWidth: true }
            AppButton { kind: "secondary"; text: "Cancel"; onClicked: root.close() }
            AppButton { kind: "primary"; text: "Add draft event"; onClicked: root.submit() }
        }
    }
}
