import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// 03 · Venues — every venue with its plan, zones and upcoming events.
ScrollView {
    id: root
    signal openSeats(string eventId)
    property alias content: body

    contentWidth: availableWidth
    clip: true

    property var modes: ({})          // venueId -> "zones" | "availability"
    function modeOf(id) { return modes[id] || "zones" }
    function setMode(id, m) { const n = Object.assign({}, modes); n[id] = m; modes = n }

    readonly property var totals: app.totals

    Column {
        id: body
        width: root.availableWidth
        bottomPadding: 56

        RowLayout {
            x: Theme.gutter; width: parent.width - 2 * Theme.gutter
            height: 330
            Column {
                Layout.alignment: Qt.AlignBottom
                Text { text: "VENUES"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
                Text { topPadding: 10; text: "THREE STAGES."; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 104; lineHeight: 0.84; color: Theme.ink }
                Text { text: "ONE BOX OFFICE."; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 104; lineHeight: 0.84; color: Theme.amber }
            }
            Item { Layout.fillWidth: true }
            Row {
                Layout.alignment: Qt.AlignBottom
                Repeater {
                    model: [
                        [app.venues.length, "Venues"],
                        [app.venues.reduce((a, v) => a + v.capacity, 0), "Seats in total"],
                        [root.totals.eventsOnSale, "Events on sale"]
                    ]
                    Item {
                        width: 170; height: 100
                        Rectangle { width: parent.width; height: 1; color: Theme.line }
                        Rectangle { visible: index > 0; width: 1; height: parent.height; color: Theme.lineSoft }
                        Column {
                            x: index > 0 ? 28 : 0; y: 16
                            Text { text: modelData[0]; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 52; color: Theme.ink }
                            Text { text: modelData[1].toUpperCase(); font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: Theme.muted }
                        }
                    }
                }
            }
        }

        Repeater {
            model: app.venues
            Column {
                id: venueBlock
                readonly property var venue: modelData
                readonly property var next: venue.events.length ? venue.events[0] : null
                readonly property string mode: root.modeOf(venue.id)
                x: Theme.gutter; width: root.availableWidth - 2 * Theme.gutter
                topPadding: 40

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.16) }
                RowLayout {
                    width: parent.width
                    spacing: 44
                    Column {
                        Layout.preferredWidth: 440
                        Layout.alignment: Qt.AlignTop
                        topPadding: 34
                        spacing: 18
                        Text { text: "0" + (index + 1) + " · " + venueBlock.venue.layout; font.family: Theme.mono; font.pixelSize: 13; color: Theme.amber }
                        Text { width: parent.width; text: venueBlock.venue.name.toUpperCase(); wrapMode: Text.WordWrap
                               font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 58; lineHeight: 0.88; color: Theme.ink }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.3
                            text: venueBlock.venue.layoutCode === "FAN" ? "Our flagship hall. Curved rows give every seat a clear line to the stage — built for talks, recitals and performances."
                                : venueBlock.venue.layoutCode === "FLAT" ? "A flexible, level-floor hall beside the labs. Ideal for showcases, demos and workshops where the action happens up close."
                                : "Stepped tiers wrap around an open stage under the sky — the home of our evening concerts and festivals."
                            font.family: Theme.body; font.pixelSize: 16; color: Theme.ink2
                        }
                        GridLayout {
                            width: parent.width
                            columns: 2; columnSpacing: 24; rowSpacing: 0
                            Repeater {
                                model: [
                                    ["CAPACITY", String(venueBlock.venue.capacity), venueBlock.venue.grid, true],
                                    ["LAYOUT", venueBlock.venue.layout, "Centre aisle · 2 exits", false],
                                    ["VIP", venueBlock.venue.vipRowsText + " · " + venueBlock.venue.vipCapacity + " seats", "Armchairs with side rests", false],
                                    ["REGULAR", venueBlock.venue.regularRowsText + " · " + venueBlock.venue.regularCapacity + " seats", "Standard seats", false]
                                ]
                                Column {
                                    Layout.fillWidth: true
                                    topPadding: 14; bottomPadding: 14; spacing: 6
                                    Rectangle { width: parent.width; height: 1; color: Theme.line }
                                    Text { topPadding: 10; text: modelData[0]; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: modelData[0] === "VIP" ? Theme.vip : Theme.muted }
                                    Text { text: modelData[1]; font.family: modelData[3] ? Theme.display : Theme.body; font.variableAxes: modelData[3] ? Theme.displayAxes : ({})
                                           font.weight: modelData[3] ? Font.Black : Font.DemiBold; font.pixelSize: modelData[3] ? 40 : 16; color: Theme.ink }
                                    Text { text: modelData[2]; font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted }
                                }
                            }
                        }
                        Text { text: "COMING UP HERE"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
                        Text { visible: venueBlock.venue.events.length === 0; text: "No events on sale yet."; font.family: Theme.body; font.pixelSize: 15; color: "#C9C2B6" }
                        Repeater {
                            model: venueBlock.venue.events
                            RowLayout {
                                width: 440; height: 60
                                spacing: 12
                                Rectangle { width: 6; height: 36; radius: 3; color: Theme.look(modelData.id, modelData.title, modelData.category).accent }
                                Column {
                                    Layout.fillWidth: true
                                    Text { text: modelData.title; font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 15; color: Theme.ink }
                                    Text { text: modelData.dayLabel + " · " + modelData.startText + " · " + modelData.vipPriceText + " / " + modelData.regularPriceText
                                           font.family: Theme.mono; font.pixelSize: 11; color: Theme.muted }
                                }
                                AppButton {
                                    implicitHeight: 40; leftPadding: 16; rightPadding: 16
                                    kind: "outlineAmber"; textSize: 13
                                    text: modelData.remaining + " left  →"
                                    Accessible.name: "Choose seats for " + modelData.title + ", " + modelData.remaining + " seats left"
                                    onClicked: root.openSeats(modelData.id)
                                }
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        topPadding: 34
                        spacing: 14
                        RowLayout {
                            width: parent.width
                            Text {
                                text: (venueBlock.mode === "availability" && venueBlock.next
                                       ? "Availability · " + venueBlock.next.title + " · " + venueBlock.next.dayLabel
                                       : "Seating plan · " + venueBlock.venue.capacity + " seats").toUpperCase()
                                font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: Theme.muted
                            }
                            Item { Layout.fillWidth: true }
                            Row {
                                visible: venueBlock.next !== null
                                Repeater {
                                    model: venueBlock.next ? [["zones", "SEATING ZONES"], ["availability", "AVAILABILITY · " + Theme.shortTitle(venueBlock.next).toUpperCase()]] : []
                                    Button {
                                        id: modeBtn
                                        implicitHeight: 36; leftPadding: 14; rightPadding: 14
                                        checkable: true; checked: venueBlock.mode === modelData[0]
                                        onClicked: root.setMode(venueBlock.venue.id, modelData[0])
                                        contentItem: Text { text: modelData[1]; font.family: Theme.mono; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                                                            color: modeBtn.checked ? Theme.bg : "#C9C2B6" }
                                        background: Rectangle { color: modeBtn.checked ? Theme.ink : "transparent"
                                                                border.color: modeBtn.checked ? Theme.ink : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.22)
                                                                Rectangle { anchors.fill: parent; anchors.margins: -3; color: "transparent"; border.color: Theme.amber; border.width: 2; visible: modeBtn.visualFocus } }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width; height: plan.height + 32
                            radius: 8; color: Theme.surface2
                            border.color: Theme.lineSoft
                            VenuePlan {
                                id: plan
                                y: 16; width: parent.width - 32; x: 16
                                height: width * 470 / 920
                                venueId: venueBlock.venue.id
                                eventId: venueBlock.next ? venueBlock.next.id : ""
                                mode: venueBlock.mode === "availability" ? "seats" : "zones"
                                interactive: false
                            }
                        }
                        Row {
                            spacing: 26
                            Repeater {
                                model: venueBlock.mode === "availability"
                                       ? [["VIP", true, "available"], ["Regular", false, "available"], ["Taken for " + (venueBlock.next ? Theme.shortTitle(venueBlock.next) : ""), false, "booked"]]
                                       : [["VIP", true, "available"], ["Regular", false, "available"]]
                                Row {
                                    spacing: 8
                                    SeatGlyph { width: 22; height: 21; vip: modelData[1]; seatState: modelData[2]; interactive: false; activeFocusOnTab: false }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; font.family: Theme.mono; font.pixelSize: 12; color: "#C9C2B6" }
                                }
                            }
                            Row {
                                spacing: 8
                                Rectangle { width: 18; height: 13; color: "transparent"; border.color: Theme.ok; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Exit"; font.family: Theme.mono; font.pixelSize: 12; color: "#C9C2B6" }
                            }
                        }
                    }
                }
            }
        }
    }
}
