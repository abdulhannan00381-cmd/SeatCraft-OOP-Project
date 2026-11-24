import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// 04 · Ticket & bookings — the selected booking as a ticket, plus search and cancellation.
ScrollView {
    id: root
    property string eventId: ""
    property string bookingId: ""
    signal select(string eventId, string bookingId)
    signal bookMore(string eventId)
    property alias content: body

    contentWidth: availableWidth
    clip: true

    property string query: ""
    property string filter: "All"
    property bool confirmOpen: false
    property string flash: ""
    property string savedFolder: ""
    property bool autoDownload: false        // set when arriving from "Download ticket" after booking

    readonly property var all: (app.revision, app.searchBookings("", "All"))
    readonly property var list: (app.revision, app.searchBookings(query, filter))
    readonly property string curE: eventId || (all.length ? all[0].eventId : "")
    readonly property string curB: bookingId || (all.length ? all[0].bookingId : "")
    readonly property var b: (app.revision, app.bookingDetails(curE, curB))
    readonly property int confirmedCount: all.filter((x) => x.confirmed).length

    onCurBChanged: { confirmOpen = false; savedFolder = ""; if (!autoDownload) flash = "" }

    // Renders the ticket card at 2x and saves it as PDF + PNG (Downloads\SeatCraft Tickets).
    function downloadTicket() {
        if (!b.found) return
        ticketCard.grabToImage((r) => {
            const out = app.saveTicket(r.image, curE, curB)
            flash = out.message
            savedFolder = out.ok ? out.folder : ""
        }, Qt.size(ticketCard.width * 2, ticketCard.height * 2))
    }
    Timer { id: autoTimer; interval: 600; onTriggered: { root.autoDownload = false; root.downloadTicket() } }
    onAutoDownloadChanged: if (autoDownload) autoTimer.restart()

    function doCancel() {
        const r = app.cancelBooking(curE, curB)
        confirmOpen = false
        flash = r.ok ? "Booking " + curB + " has been cancelled. " + b.seatsAnd + (b.count > 1 ? " are" : " is") + " now available again for " + b.eventTitle + "." : r.message
    }

    Column {
        id: body
        width: root.availableWidth

        RowLayout {
            width: parent.width
            spacing: 0

            // ------------------------------------------------ ticket
            Column {
                id: main
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                leftPadding: Theme.gutter; rightPadding: 48; topPadding: 34; bottomPadding: 48
                spacing: 26
                readonly property real inner: width - leftPadding - rightPadding

                Text {
                    visible: !root.b.found
                    text: "No bookings yet. Book seats from Discover and they will appear here."
                    font.family: Theme.body; font.pixelSize: 16; color: "#C9C2B6"
                }

                RowLayout {
                    visible: root.b.found
                    width: main.inner
                    Column {
                        Text { text: "BOOKING " + root.curE + " · " + root.curB; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
                        Text { topPadding: 8; text: "YOUR TICKET"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 72; color: Theme.ink }
                    }
                    Item { Layout.fillWidth: true }
                    AppButton { visible: root.b.found === true; kind: "outlineAmber"; text: "Download ticket  ↓"; Accessible.name: "Download ticket as PDF and image"; onClicked: root.downloadTicket() }
                    AppButton { visible: root.b.confirmed === true; kind: "danger"; text: "Cancel booking"; onClicked: { root.confirmOpen = true; root.flash = ""; root.savedFolder = "" } }
                    AppButton { kind: "secondary"; text: "Book more seats"; onClicked: root.bookMore(root.curE) }
                }

                // ticket card
                Rectangle {
                    id: ticketCard
                    visible: root.b.found
                    width: main.inner; height: 330
                    radius: 10; color: Theme.ink; clip: true
                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        EventArt {
                            Layout.preferredWidth: 230; Layout.fillHeight: true
                            eventId: root.curE
                            Column {
                                anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 20
                                Text { text: Theme.shortTitle({ id: root.curE, title: root.b.eventTitle || "" }).toUpperCase(); font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 30; color: "white" }
                                Text { text: (root.curE + " · " + (root.b.category || "")).toUpperCase(); font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.4; color: Qt.rgba(1, 1, 1, 0.8) }
                            }
                        }
                        Column {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            padding: 30; spacing: 22
                            Text { text: "ADMIT " + (root.b.count || 0) + " · " + (root.b.categoryLine || ""); font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: "#6B6358" }
                            Text { width: parent.width - 60; height: 56; text: (root.b.eventTitle || "").toUpperCase()
                                   fontSizeMode: Text.HorizontalFit; minimumPixelSize: 28; verticalAlignment: Text.AlignBottom
                                   font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 48; color: "#14110D" }
                            Row {
                                id: fields
                                width: parent.width - 60
                                spacing: 22
                                Repeater {
                                    model: [["DATE", root.b.displayDate], ["TIME", root.b.timeRange], ["VENUE", root.b.venueName], ["NAME", root.b.customer]]
                                    Column {
                                        width: (fields.width - 3 * fields.spacing) / 4
                                        spacing: 6
                                        Text { text: modelData[0]; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.4; color: "#6B6358" }
                                        Text { width: parent.width; text: modelData[1] || ""; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                               font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 15; color: "#14110D" }
                                    }
                                }
                            }
                            Row {
                                spacing: 28
                                Column {
                                    Text { text: "SEATS"; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.4; color: "#6B6358" }
                                    Text { text: root.b.seatsText || ""; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 62; color: "#14110D" }
                                }
                                Text { anchors.bottom: parent.bottom; bottomPadding: 10; text: "Show this ticket at the entrance"; font.family: Theme.mono; font.pixelSize: 12; color: "#6B6358" }
                            }
                        }
                        // perforation
                        Item {
                            Layout.preferredWidth: 2; Layout.fillHeight: true
                            Column { spacing: 6; y: 16; Repeater { model: 22; Rectangle { width: 2; height: 7; color: Qt.rgba(20 / 255, 17 / 255, 13 / 255, 0.25) } } }
                            Rectangle { x: -13; y: -13; width: 26; height: 26; radius: 13; color: Theme.bg }
                            Rectangle { x: -13; y: parent.height - 13; width: 26; height: 26; radius: 13; color: Theme.bg }
                        }
                        Column {
                            Layout.preferredWidth: 190; Layout.fillHeight: true
                            padding: 26; spacing: 18
                            Column {
                                Text { text: "BOOKING"; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.4; color: "#6B6358" }
                                Text { text: root.curB; font.family: Theme.mono; font.pixelSize: 20; color: "#14110D" }
                            }
                            Column {
                                Text { text: "ADMIT"; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.4; color: "#6B6358" }
                                Text { text: root.b.count || 0; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 88; color: "#14110D" }
                            }
                            Column {
                                Text { text: "TOTAL"; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1.4; color: "#6B6358" }
                                Text { text: root.b.totalText || ""; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 26; color: "#14110D" }
                            }
                        }
                    }
                    Rectangle {
                        visible: root.b.confirmed === false
                        anchors.fill: parent
                        color: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.55)
                        Rectangle {
                            anchors.centerIn: parent
                            rotation: -8
                            width: stamp.implicitWidth + 52; height: stamp.implicitHeight + 8
                            color: "transparent"; radius: 6
                            border.color: "#C8341F"; border.width: 5
                            Text { id: stamp; anchors.centerIn: parent; text: "CANCELLED"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 84; font.letterSpacing: 4; color: "#C8341F" }
                        }
                    }
                }

                // tickets + locator
                RowLayout {
                    visible: root.b.found
                    width: main.inner
                    spacing: 28
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Rectangle { width: parent.width; height: 1; color: Theme.line }
                        Text { topPadding: 14; bottomPadding: 4; text: "ONE TICKET PER SEAT"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
                        Repeater {
                            model: root.b.tickets || []
                            Column {
                                width: parent.width
                                Row {
                                    height: 66; spacing: 16
                                    Text { width: 64; anchors.verticalCenter: parent.verticalCenter; text: modelData.seat; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 36; color: Theme.ink }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: modelData.id; font.family: Theme.mono; font.pixelSize: 13; color: Theme.ink }
                                        Text { text: modelData.category + " · " + modelData.priceText; font.family: Theme.body; font.pixelSize: 13; color: Theme.muted }
                                    }
                                }
                                Rectangle { width: parent.width; height: 1; color: Theme.lineSoft }
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 340
                        Layout.preferredHeight: loc.implicitHeight + 32
                        Layout.alignment: Qt.AlignTop
                        radius: 6; color: Theme.surface; border.color: Theme.lineSoft
                        Column {
                            id: loc
                            x: 18; y: 16; width: parent.width - 36; spacing: 10
                            RowLayout {
                                width: parent.width
                                Text { text: "WHERE YOU'RE SITTING"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: Theme.ink }
                                Item { Layout.fillWidth: true }
                                Text { text: (root.b.venueName || "").toUpperCase(); font.family: Theme.mono; font.pixelSize: 10; color: Theme.muted; elide: Text.ElideRight; Layout.maximumWidth: 150 }
                            }
                            VenuePlan {
                                width: parent.width; height: width * 470 / 920
                                venueId: root.b.venueId || ""; eventId: root.curE
                                mode: "locator"; interactive: false
                                highlight: root.b.seats || []
                                dimHighlight: root.b.confirmed === false
                                Accessible.role: Accessible.Graphic
                                Accessible.name: "Seat locator. " + (root.b.seatsAnd || "")
                            }
                            Text { width: parent.width; wrapMode: Text.WordWrap
                                   text: (root.b.confirmed === false ? "Released: " : "Your seats: ") + (root.b.seatsText || "") + (root.b.venueId === "MA" ? " · enter by the centre aisle" : " · nearest exit on the side aisle")
                                   font.family: Theme.mono; font.pixelSize: 11; color: Theme.muted }
                        }
                    }
                }

                // cancel confirmation
                Rectangle {
                    visible: root.confirmOpen && root.b.confirmed === true
                    width: main.inner; height: 112
                    radius: 6
                    color: Qt.rgba(1, 107 / 255, 94 / 255, 0.07)
                    border.color: Qt.rgba(1, 107 / 255, 94 / 255, 0.55)
                    Accessible.role: Accessible.AlertMessage
                    Accessible.name: "Cancel the whole booking?"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 24
                        spacing: 24
                        Column {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "CANCEL THE WHOLE BOOKING?"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 28; color: Theme.ink }
                            Text { width: parent.width; wrapMode: Text.WordWrap
                                   text: (root.b.seatsAnd || "") + " will be released for " + (root.b.eventTitle || "") + " and become available to other guests. The booking stays in history as Cancelled. This can't be undone."
                                   font.family: Theme.body; font.pixelSize: 14; color: Theme.ink2 }
                        }
                        AppButton { kind: "secondary"; text: "Keep booking"; onClicked: root.confirmOpen = false }
                        AppButton { kind: "danger"; text: "Confirm cancellation"; onClicked: root.doCancel() }
                    }
                }
                Rectangle {
                    visible: root.flash !== ""
                    width: main.inner; height: 48
                    color: Qt.rgba(127 / 255, 214 / 255, 164 / 255, 0.08)
                    Rectangle { width: 2; height: parent.height; color: Theme.ok }
                    Text { x: 18; width: parent.width - 180; elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter; text: root.flash; font.family: Theme.body; font.pixelSize: 14; color: "#BFF0D2" }
                    NavLink { visible: root.savedFolder !== ""; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                              text: "Open folder"; onClicked: app.openFolder(root.savedFolder) }
                    Accessible.role: Accessible.AlertMessage
                    Accessible.name: root.flash
                }

                // info row
                Row {
                    visible: root.b.found
                    Repeater {
                        model: [
                            ["REFERENCE", root.curE + " · " + root.curB, Theme.ink],
                            ["EVENT DATE", root.b.displayDate || "", Theme.ink],
                            ["ISSUED BY", "Box office · Desk 01", Theme.ink],
                            ["STATUS", root.b.status || "", root.b.confirmed ? Theme.ok : "#FF8A7E"]
                        ]
                        Item {
                            width: main.inner / 4; height: 70
                            Rectangle { width: parent.width; height: 1; color: Theme.line }
                            Rectangle { visible: index > 0; width: 1; height: parent.height; color: Theme.lineSoft }
                            Column {
                                x: index > 0 ? 18 : 0; y: 16; spacing: 6
                                Text { text: modelData[0]; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: Theme.muted }
                                Text { text: modelData[1]; font.family: index === 0 ? Theme.mono : Theme.body; font.pixelSize: 14; color: modelData[2] }
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------ list
            Rectangle {
                Layout.preferredWidth: 440
                Layout.fillHeight: true
                Layout.minimumHeight: side.implicitHeight + 40
                color: Theme.surface
                Rectangle { width: 1; height: parent.height; color: Theme.lineSoft }
                Column {
                    id: side
                    width: parent.width
                    topPadding: 34
                    spacing: 16
                    Column {
                        x: 28
                        Text { text: "BOOKINGS"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 36; color: Theme.ink }
                        Text { text: root.all.length + " records · " + root.confirmedCount + " confirmed · " + (root.all.length - root.confirmedCount) + " cancelled"
                               font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted }
                    }
                    Column {
                        x: 28; width: parent.width - 56; spacing: 8
                        Text { text: "SEARCH BY BOOKING ID OR NAME"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: Theme.muted }
                        TextField {
                            id: search
                            width: parent.width; implicitHeight: 50
                            placeholderText: "e.g. BKG-0013 or Ayesha"
                            placeholderTextColor: Theme.dim
                            color: Theme.ink; font.family: Theme.body; font.pixelSize: 15
                            leftPadding: 16
                            onTextEdited: root.query = text
                            Accessible.name: "Search bookings"
                            background: Rectangle { radius: Theme.radius; color: Theme.bg
                                                    border.color: search.activeFocus ? Theme.amber : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.25)
                                                    border.width: search.activeFocus ? 2 : 1 }
                        }
                    }
                    Row {
                        x: 28
                        Repeater {
                            model: ["All", "Confirmed", "Cancelled"]
                            Button {
                                id: fb
                                implicitHeight: 36; leftPadding: 14; rightPadding: 14
                                checkable: true; checked: root.filter === modelData
                                onClicked: root.filter = modelData
                                contentItem: Text { text: modelData; font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                                                    color: fb.checked ? Theme.bg : "#C9C2B6" }
                                background: Rectangle { color: fb.checked ? Theme.ink : "transparent"
                                                        border.color: fb.checked ? Theme.ink : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.2)
                                                        Rectangle { anchors.fill: parent; anchors.margins: -3; color: "transparent"; border.color: Theme.amber; border.width: 2; visible: fb.visualFocus } }
                            }
                        }
                    }
                    Column {
                        width: parent.width
                        Rectangle { width: parent.width; height: 1; color: Theme.lineSoft }
                        ListView {
                            width: side.width
                            height: Math.min(contentHeight, 92 * 7)
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            model: root.list
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool on: modelData.eventId === root.curE && modelData.bookingId === root.curB
                                width: side.width; height: 92
                                color: on ? Qt.rgba(245 / 255, 181 / 255, 68 / 255, 0.07) : rowHover.hovered ? Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.04) : "transparent"
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.bookingId + ", " + modelData.customer + ", " + modelData.eventTitle + ", " + modelData.status
                                Keys.onReturnPressed: root.select(modelData.eventId, modelData.bookingId)
                                Rectangle { width: 3; height: parent.height; color: parent.on ? Theme.amber : "transparent" }
                                GridLayout {
                                    x: 20; y: 14; width: parent.width - 40
                                    columns: 2; rowSpacing: 4
                                    Text { text: modelData.eventId + " · " + modelData.bookingId; font.family: Theme.mono; font.pixelSize: 13; color: Theme.ink; Layout.fillWidth: true }
                                    Row { spacing: 6; Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: modelData.confirmed ? Theme.ok : "#FF8A7E" }
                                          Text { text: modelData.status; font.family: Theme.body; font.pixelSize: 12; color: modelData.confirmed ? Theme.ok : "#FF8A7E" } }
                                    Text { text: modelData.customer; font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 15; color: Theme.ink }
                                    Text { Layout.alignment: Qt.AlignRight; text: modelData.seats; font.family: Theme.mono; font.pixelSize: 12; color: "#C9C2B6" }
                                    Text { Layout.columnSpan: 2; text: modelData.eventTitle + " · " + modelData.totalText; font.family: Theme.body; font.pixelSize: 12; color: Theme.muted }
                                }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
                                Rectangle { anchors.fill: parent; color: "transparent"; border.color: Theme.amber; border.width: 2; visible: parent.activeFocus }
                                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { root.select(modelData.eventId, modelData.bookingId); root.flash = "" } }
                            }
                        }
                        Text {
                            visible: root.list.length === 0
                            x: 28; width: side.width - 56; topPadding: 20; wrapMode: Text.WordWrap
                            text: "No booking matches “" + root.query + "”. Check the ID (e.g. BKG-0013) or try part of the customer's name."
                            font.family: Theme.body; font.pixelSize: 14; color: "#C9C2B6"
                        }
                    }
                }
            }
        }
    }
}
