import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// 02 · Seat selection — works for every venue layout.
ScrollView {
    id: root
    property string eventId: "EVT01"
    signal eventChosen(string id)
    signal openTicket(string eventId, string bookingId)
    signal downloadTicket(string eventId, string bookingId)
    signal back()
    property alias content: body

    contentWidth: availableWidth
    clip: true

    property var selected: []
    property string step: "seats"           // seats | details | done
    property string customerName: ""
    property string message: ""
    property bool messageIsError: false
    property string inspected: ""
    property int qty: 2
    property string pref: "Any"
    property var done: ({})

    readonly property var ev: Object.assign({ id: "", title: "", category: "", venueId: "", venueName: "", displayDate: "", dayLabel: "",
                                              timeRange: "", vipRowsText: "", regularRowsText: "", vipPriceText: "", regularPriceText: "",
                                              vipOpen: 0, regularOpen: 0, remaining: 0, capacity: 0, onSale: false },
                                            (app.revision, app.event(eventId)))
    readonly property bool hasEvent: ev.id !== "" && ev.onSale
    readonly property var price: (app.revision, app.priceSelection(eventId, selected))
    readonly property var onSale: app.events.filter((e) => e.onSale)
    readonly property string viewSeat: inspected || (selected.length ? selected[0] : ((app.revision, app.bestTogether(eventId, 1, "Any"))[0] || ""))

    onEventIdChanged: resetFlow()
    function resetFlow() {
        selected = []; step = "seats"; message = ""; inspected = ""; done = ({})
    }
    function say(text, isError) { message = text; messageIsError = isError }

    function toggle(id) {
        if (step !== "seats") { say("Go back to seats to change your selection.", true); return }
        if (app.isSeatBooked(eventId, id)) { say("Seat " + id + " is already taken. Please choose another seat.", true); inspected = id; return }
        const i = selected.indexOf(id)
        const next = selected.slice()
        if (i >= 0) next.splice(i, 1); else next.push(id)
        selected = next
        inspected = id
        message = ""
    }
    function findBest() {
        if (step !== "seats") return
        const seats = app.bestTogether(eventId, qty, pref)
        if (seats.length === 0) {
            say("There are no " + qty + " seats together" + (pref === "Any" ? "" : " in " + pref) + ". Try fewer seats or another category.", true)
            return
        }
        selected = seats
        inspected = seats[0]
        say("Best " + qty + " seats together: " + seats.join(" · ") + " in row " + seats[0][0] + ", closest to the centre.", false)
    }
    function toDetails() {
        if (selected.length === 0) { say("Choose at least one seat to continue.", true); return }
        step = "details"; message = ""
        nameField.forceActiveFocus()
    }
    function confirm() {
        const r = app.confirmBooking(eventId, customerName, price.sorted)
        if (!r.ok) {
            say(r.message, true)
            if (r.message.indexOf("already booked") >= 0) step = "seats"
            return
        }
        done = r.details
        selected = []
        step = "done"
        message = ""
    }

    Column {
        id: body
        width: root.availableWidth

        // ---- event switcher
        Flow {
            x: Theme.gutter; width: parent.width - 2 * Theme.gutter
            topPadding: 18
            spacing: 12
            Repeater {
                model: root.onSale
                Rectangle {
                    readonly property bool on: modelData.id === root.eventId
                    width: 236; height: 74; radius: 6
                    color: on ? Qt.rgba(245 / 255, 181 / 255, 68 / 255, 0.07) : "transparent"
                    border.color: on ? Theme.amber : chipHover.hovered ? Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.35) : Theme.line
                    activeFocusOnTab: true
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.title + ", " + modelData.dayLabel + ", " + modelData.remaining + " seats left"
                    Keys.onReturnPressed: root.eventChosen(modelData.id)
                    Rectangle { x: 10; y: 10; width: 6; height: parent.height - 20; radius: 3; color: Theme.look(modelData.id, modelData.title, modelData.category).accent }
                    Column {
                        x: 28; y: 11; spacing: 3
                        Text { text: Theme.shortTitle(modelData); font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 14; color: Theme.ink }
                        Text { text: modelData.dayLabel + " · " + modelData.startText + " · " + modelData.venueName.split(" ")[0]
                               font.family: Theme.mono; font.pixelSize: 11; color: Theme.muted }
                        Text { text: modelData.remaining + " seats left"; font.family: Theme.mono; font.pixelSize: 11
                               color: modelData.remaining <= 10 ? Theme.amber : Theme.muted }
                    }
                    Rectangle { anchors.fill: parent; anchors.margins: -3; radius: 8; color: "transparent"; border.color: Theme.amber; border.width: 2; visible: parent.activeFocus }
                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.eventChosen(modelData.id) }
                }
            }
        }

        Column {
            visible: !root.hasEvent
            x: Theme.gutter; topPadding: 60; spacing: 16
            Text { text: root.onSale.length ? "CHOOSE AN EVENT ABOVE" : "NOTHING TO BOOK YET"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 64; color: Theme.ink }
            Text { text: root.onSale.length ? "Pick an event to see its seating plan." : "Publish an event in the Organizer and its seating plan will appear here."
                   font.family: Theme.body; font.pixelSize: 17; color: Theme.ink2 }
            AppButton { kind: "secondary"; text: "← Back to Discover"; onClicked: root.back() }
        }

        // ---- event header
        RowLayout {
            visible: root.hasEvent
            x: Theme.gutter; width: parent.width - 2 * Theme.gutter
            height: 128
            spacing: 22
            AppButton { implicitWidth: 44; implicitHeight: 44; leftPadding: 0; rightPadding: 0; text: "←"; Accessible.name: "Back to Discover"; onClicked: root.back() }
            EventArt { Layout.preferredWidth: 54; Layout.preferredHeight: 78; eventId: root.eventId; radius: 4 }
            Column {
                Layout.fillWidth: true
                spacing: 4
                Text { text: (root.ev.category + " · " + root.ev.venueName).toUpperCase(); font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.stageEdge }
                Text { text: root.ev.title.toUpperCase(); font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 46; color: Theme.ink }
                Text { text: (root.ev.displayDate + " · " + root.ev.timeRange + " · " + root.ev.venueName).toUpperCase(); font.family: Theme.mono; font.pixelSize: 13; color: "#C9C2B6" }
            }
            Row {
                spacing: 26
                Repeater {
                    model: [["01", "SEATS", "seats"], ["02", "DETAILS", "details"], ["03", "CONFIRMED", "done"]]
                    Row {
                        spacing: 10
                        readonly property int me: ["seats", "details", "done"].indexOf(modelData[2])
                        readonly property int now: ["seats", "details", "done"].indexOf(root.step)
                        Text { text: modelData[0]; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 20
                               color: parent.me === parent.now ? Theme.amber : parent.me < parent.now ? Theme.muted : Theme.dim }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; font.family: Theme.mono; font.pixelSize: 12; font.letterSpacing: 1.2
                               color: parent.me === parent.now ? Theme.ink : parent.me < parent.now ? Theme.muted : Theme.dim }
                    }
                }
            }
        }
        Rectangle { visible: root.hasEvent; width: parent.width; height: 1; color: Theme.lineSoft }

        RowLayout {
            visible: root.hasEvent
            width: parent.width
            spacing: 0

            // ---- plan
            Column {
                id: planColumn
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                leftPadding: Theme.gutter; rightPadding: 40; topPadding: 22; bottomPadding: 30
                spacing: 12
                readonly property real inner: width - leftPadding - rightPadding

                RowLayout {
                    width: planColumn.inner
                    Text {
                        textFormat: Text.StyledText
                        text: "<font color='" + Theme.vip + "'>VIP</font> · " + root.ev.vipRowsText.toUpperCase() + " · " + root.ev.vipPriceText + " · " + root.ev.vipOpen + " open"
                              + "&nbsp;&nbsp;&nbsp;&nbsp;REGULAR · " + root.ev.regularRowsText.toUpperCase() + " · " + root.ev.regularPriceText + " · " + root.ev.regularOpen + " open"
                        font.family: Theme.mono; font.pixelSize: 12; color: "#C9C2B6"
                    }
                    Item { Layout.fillWidth: true }
                    Text { text: root.ev.remaining + " of " + root.ev.capacity + " seats open"; font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted }
                }

                Row {
                    spacing: 14
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "BEST SEATS TOGETHER"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.ink }
                    Row {
                        AppButton { implicitWidth: 36; implicitHeight: 36; leftPadding: 0; rightPadding: 0; text: "−"; Accessible.name: "Fewer seats"; onClicked: root.qty = Math.max(1, root.qty - 1) }
                        Text { width: 40; height: 36; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: root.qty; font.family: Theme.mono; font.pixelSize: 15; color: Theme.ink }
                        AppButton { implicitWidth: 36; implicitHeight: 36; leftPadding: 0; rightPadding: 0; text: "+"; Accessible.name: "More seats"; onClicked: root.qty = Math.min(6, root.qty + 1) }
                    }
                    Row {
                        Repeater {
                            model: ["Any", "VIP", "Regular"]
                            Button {
                                id: segBtn
                                implicitHeight: 36; leftPadding: 12; rightPadding: 12
                                checkable: true; checked: root.pref === modelData
                                onClicked: root.pref = modelData
                                Accessible.name: "Prefer " + modelData
                                contentItem: Text { text: modelData.toUpperCase(); font.family: Theme.mono; font.pixelSize: 12
                                                    color: segBtn.checked ? Theme.bg : "#C9C2B6"; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: segBtn.checked ? Theme.ink : "transparent"
                                                        border.color: segBtn.checked ? Theme.ink : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.22)
                                                        Rectangle { anchors.fill: parent; anchors.margins: -3; color: "transparent"; border.color: Theme.amber; border.width: 2; visible: segBtn.visualFocus } }
                            }
                        }
                    }
                    AppButton { implicitHeight: 36; kind: "outlineAmber"; text: "Find seats"; textSize: 13; onClicked: root.findBest() }
                }

                Item {
                    width: planColumn.inner; height: 40
                    Rectangle {
                        visible: root.message !== ""
                        height: 38; width: msg.implicitWidth + 30
                        color: root.messageIsError ? Qt.rgba(1, 107 / 255, 94 / 255, 0.10) : Qt.rgba(245 / 255, 181 / 255, 68 / 255, 0.08)
                        Rectangle { width: 2; height: parent.height; color: root.messageIsError ? Theme.danger : Theme.amber }
                        Text { id: msg; x: 16; anchors.verticalCenter: parent.verticalCenter; text: root.message
                               font.family: Theme.body; font.pixelSize: 14; color: root.messageIsError ? "#FFC2BB" : "#FFE2A6" }
                        Accessible.role: Accessible.AlertMessage
                        Accessible.name: root.message
                    }
                }

                VenuePlan {
                    width: Math.min(planColumn.inner, 960); height: width * 470 / 920
                    anchors.horizontalCenter: parent.horizontalCenter
                    venueId: root.ev.venueId; eventId: root.eventId
                    selected: root.selected
                    inspected: root.viewSeat
                    vipPriceText: root.ev.vipPriceText; regularPriceText: root.ev.regularPriceText
                    onSeatPicked: (id) => root.toggle(id)
                    onSeatLooked: (id) => root.inspected = id
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 34
                    Repeater {
                        model: [
                            { label: "Regular · " + root.ev.regularPriceText, vip: false, st: "available" },
                            { label: "VIP armchair · " + root.ev.vipPriceText, vip: true, st: "available" },
                            { label: "Your selection", vip: false, st: "selected" },
                            { label: "Taken", vip: false, st: "booked" }
                        ]
                        Row {
                            spacing: 10
                            SeatGlyph { width: 26; height: 25; vip: modelData.vip; seatState: modelData.st; interactive: false; number: 0; activeFocusOnTab: false }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.family: Theme.body; font.pixelSize: 13; color: "#C9C2B6" }
                        }
                    }
                }
            }

            // ---- summary rail
            Rectangle {
                Layout.preferredWidth: 420
                Layout.fillHeight: true
                Layout.minimumHeight: rail.implicitHeight + 60
                color: Theme.surface
                Rectangle { width: 1; height: parent.height; color: Theme.lineSoft }

                Column {
                    id: rail
                    x: 32; y: 28; width: parent.width - 64
                    spacing: 18

                    // seats / details
                    Column {
                        visible: root.step !== "done"
                        width: parent.width
                        spacing: 18

                        RowLayout {
                            width: parent.width
                            Text { text: "YOUR SEATS"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 32; color: Theme.ink }
                            Item { Layout.fillWidth: true }
                            Text { text: root.selected.length + (root.selected.length === 1 ? " seat" : " seats"); font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted }
                        }
                        Text {
                            visible: root.selected.length === 0
                            width: parent.width; wrapMode: Text.WordWrap
                            text: "Choose any open seat, or let us find the best seats together. Armchairs in " + root.ev.vipRowsText.replace("Rows", "rows").replace("Row", "row") + " are VIP."
                            font.family: Theme.body; font.pixelSize: 15; lineHeight: 1.25; color: "#C9C2B6"
                        }
                        Column {
                            width: parent.width
                            Repeater {
                                model: root.price.items || []
                                RowLayout {
                                    width: rail.width; height: 64
                                    spacing: 16
                                    Text { Layout.preferredWidth: 62; text: modelData.id; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 34; color: Theme.ink }
                                    Column {
                                        Layout.fillWidth: true
                                        Text { text: "Row " + modelData.row + " · Seat " + modelData.number; font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 14; color: Theme.ink }
                                        Text { text: modelData.category + " · " + modelData.priceText; font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted }
                                    }
                                    AppButton {
                                        visible: root.step === "seats"
                                        implicitWidth: 32; implicitHeight: 32; leftPadding: 0; rightPadding: 0
                                        text: "×"; Accessible.name: "Remove seat " + modelData.id
                                        onClicked: root.toggle(modelData.id)
                                    }
                                }
                            }
                        }
                        ViewFromSeat { width: parent.width; eventId: root.eventId; seatId: root.viewSeat; visible: root.viewSeat !== "" }

                        // ticket perforation
                        Item {
                            width: parent.width; height: 18
                            Rectangle { x: -41; y: 0; width: 18; height: 18; radius: 9; color: Theme.bg }
                            Rectangle { x: parent.width + 23; y: 0; width: 18; height: 18; radius: 9; color: Theme.bg }
                            Row { y: 8; spacing: 5; Repeater { model: Math.max(0, Math.floor(rail.width / 9)); Rectangle { width: 4; height: 1; color: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.25) } } }
                        }
                        Repeater {
                            model: root.price.lines || []
                            RowLayout {
                                width: rail.width
                                Text { text: modelData.label; font.family: Theme.body; font.pixelSize: 14; color: "#C9C2B6" }
                                Item { Layout.fillWidth: true }
                                Text { text: modelData.amount; font.family: Theme.mono; font.pixelSize: 14; color: "#C9C2B6" }
                            }
                        }
                        RowLayout {
                            width: parent.width
                            Text { Layout.alignment: Qt.AlignBottom; text: "TOTAL"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
                            Item { Layout.fillWidth: true }
                            Text { text: root.price.totalText || "Rs 0"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 54; color: Theme.ink }
                        }
                        Text { anchors.right: parent.right; text: "No booking fees"; font.family: Theme.mono; font.pixelSize: 11; color: Theme.dim }

                        Column {
                            visible: root.step === "seats"
                            width: parent.width; spacing: 12
                            AppButton { width: parent.width; implicitHeight: 54; kind: "primary"; text: "Continue"; onClicked: root.toDetails() }
                            Text { width: parent.width; wrapMode: Text.WordWrap; text: "Seats aren't reserved until you confirm the booking."; font.family: Theme.body; font.pixelSize: 13; color: Theme.muted }
                        }
                        Column {
                            visible: root.step === "details"
                            width: parent.width; spacing: 12
                            Text { text: "CUSTOMER NAME"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
                            TextField {
                                id: nameField
                                width: parent.width; implicitHeight: 52
                                text: root.customerName
                                onTextEdited: root.customerName = text
                                onAccepted: root.confirm()
                                placeholderText: "Full name"
                                placeholderTextColor: Theme.dim
                                color: Theme.ink
                                font.family: Theme.body; font.pixelSize: 16
                                leftPadding: 16
                                Accessible.name: "Customer name"
                                background: Rectangle { radius: Theme.radius; color: Theme.bg
                                                        border.color: nameField.activeFocus ? Theme.amber : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.3)
                                                        border.width: nameField.activeFocus ? 2 : 1 }
                            }
                            AppButton { width: parent.width; implicitHeight: 54; kind: "primary"; text: "Confirm booking"; onClicked: root.confirm() }
                            AppButton { width: parent.width; kind: "secondary"; text: "Back to seats"; onClicked: { root.step = "seats"; root.message = "" } }
                            Text { width: parent.width; wrapMode: Text.WordWrap; text: "We'll make sure these seats are still free the moment you confirm."; font.family: Theme.body; font.pixelSize: 13; color: Theme.muted }
                        }
                    }

                    // done
                    Column {
                        visible: root.step === "done"
                        width: parent.width
                        spacing: 18
                        Row {
                            spacing: 14
                            Rectangle {
                                width: 44; height: 44; radius: 22; color: Theme.ok
                                Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 22; font.bold: true; color: "#0B2A1A" }
                            }
                            Column {
                                Text { text: "REFERENCE " + (root.done.bookingId || ""); font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.ok }
                                Text { text: "BOOKING CONFIRMED"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 34; color: Theme.ink }
                            }
                        }
                        Rectangle {
                            width: parent.width; height: doneCol.implicitHeight
                            radius: 6; clip: true; color: "transparent"
                            border.color: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.18)
                            Column {
                                id: doneCol
                                width: parent.width
                                Rectangle {
                                    width: parent.width; height: 104
                                    color: Theme.look(root.eventId, root.ev.title, root.ev.category).block
                                    Column {
                                        x: 20; y: 16; spacing: 4
                                        Text { text: (Theme.shortTitle(root.ev) + " · " + root.ev.dayLabel).toUpperCase(); font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: "#E4E8FF" }
                                        Text { text: root.done.seatsText || ""; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 30; color: Theme.ink }
                                        Text { text: root.done.customer || ""; font.family: Theme.body; font.pixelSize: 14; color: Theme.ink }
                                    }
                                }
                                Column {
                                    width: parent.width; padding: 20; spacing: 8
                                    Repeater {
                                        model: root.done.tickets || []
                                        RowLayout {
                                            width: doneCol.width - 40
                                            Text { text: modelData.id + " · " + modelData.seat + " · " + modelData.category; font.family: Theme.mono; font.pixelSize: 13; color: "#C9C2B6" }
                                            Item { Layout.fillWidth: true }
                                            Text { text: modelData.priceText; font.family: Theme.mono; font.pixelSize: 13; color: "#C9C2B6" }
                                        }
                                    }
                                    Rectangle { width: doneCol.width - 40; height: 1; color: Theme.line }
                                    RowLayout {
                                        width: doneCol.width - 40
                                        Text { text: "Total"; font.family: Theme.body; font.pixelSize: 14; color: Theme.ink }
                                        Item { Layout.fillWidth: true }
                                        Text { text: root.done.totalText || ""; font.family: Theme.mono; font.pixelSize: 14; color: Theme.ink }
                                    }
                                }
                            }
                        }
                        AppButton { width: parent.width; implicitHeight: 54; kind: "primary"; text: "View ticket"; onClicked: root.openTicket(root.eventId, root.done.bookingId) }
                        AppButton { width: parent.width; kind: "outlineAmber"; text: "Download ticket (PDF + image)  ↓"; onClicked: root.downloadTicket(root.eventId, root.done.bookingId) }
                        AppButton { width: parent.width; kind: "secondary"; text: "Book more seats"; onClicked: { root.resetFlow(); root.customerName = "" } }
                    }
                }
            }
        }
    }
}
