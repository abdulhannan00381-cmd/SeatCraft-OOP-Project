import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// 05 · Organizer — programme KPIs, venue timeline, conflict resolution, events.
ScrollView {
    id: root
    signal navigate(string page)
    property alias content: body

    contentWidth: availableWidth
    clip: true

    property string weekStart: mondayOf(today)
    property string day: today

    function mondayOf(ymd) {
        const d = new Date(ymd + "T00:00:00")
        d.setDate(d.getDate() - ((d.getDay() + 6) % 7))
        return Qt.formatDate(d, "yyyy-MM-dd")
    }
    function showDate(ymd) { weekStart = mondayOf(ymd); day = ymd }
    // Open on the week that matters: a conflict first, else the next event, else today.
    Component.onCompleted: {
        const c = app.conflicts()
        const evs = app.events.slice().sort((a, b) => a.date < b.date ? -1 : a.date > b.date ? 1 : a.start - b.start)
        const next = evs.filter((e) => e.date >= today)[0] || evs[evs.length - 1]
        showDate(c.length ? c[0].date : next ? next.date : today)
    }
    property int fixIndex: 0
    property string notice: ""
    property bool noticeOk: true

    readonly property var totals: app.totals
    readonly property var conflicts: (app.revision, app.conflicts())
    readonly property var conflict: conflicts.length ? conflicts[0] : null
    readonly property var fix: conflict && conflict.fixes.length ? conflict.fixes[Math.min(fixIndex, conflict.fixes.length - 1)] : null
    readonly property var days: (app.revision, app.calendar(weekStart, 7))
    readonly property var tl: (app.revision, app.timeline(day))
    readonly property var weekEvents: app.events.filter((e) => days.some((d) => d.date === e.date))
    readonly property var sortedEvents: app.events.slice().sort((a, b) => a.date === b.date ? a.start - b.start : (a.date < b.date ? -1 : 1))
    readonly property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")

    // Timeline window: 12:00–22:00, widened if an event starts earlier or ends later.
    readonly property int t0: Math.min(720, Math.floor(Math.min.apply(null, [720].concat(tl.venues.reduce((a, v) => a.concat(v.blocks.map((b) => b.start)), []))) / 60) * 60)
    readonly property int t1: Math.max(1320, Math.ceil(Math.max.apply(null, [1320].concat(tl.venues.reduce((a, v) => a.concat(v.blocks.map((b) => b.end)), []))) / 60) * 60)

    function shiftWeek(days) {
        const d = new Date(weekStart + "T00:00:00")
        d.setDate(d.getDate() + days)
        weekStart = Qt.formatDate(d, "yyyy-MM-dd")
        day = weekStart
    }
    function applyFix() {
        if (!fix) return
        const r = app.applyFix(fix.eventId, fix.venueId, fix.start, fix.end)
        notice = r.message; noticeOk = r.ok; fixIndex = 0
    }
    function publish(id) {
        const r = app.publishEvent(id)
        notice = r.message; noticeOk = r.ok
    }

    NewEventDialog {
        id: newEvent
        onCreated: (eventId, date, message, hasConflict) => {
            root.notice = message + (hasConflict ? " It clashes with another event — see the conflict panel." : "")
            root.noticeOk = !hasConflict
            root.showDate(date)
        }
    }

    Column {
        id: body
        width: root.availableWidth

        RowLayout {
            x: Theme.gutter; width: parent.width - 2 * Theme.gutter
            height: 150
            Column {
                Layout.alignment: Qt.AlignBottom
                Text { text: "ORGANIZER · PROGRAMME"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
                Row {
                    spacing: 18
                    Text { text: "WEEK OF " + root.days[0].label.slice(4).toUpperCase() + " – " + root.days[6].label.slice(4).toUpperCase()
                           font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 72; color: Theme.ink }
                    AppButton { anchors.verticalCenter: parent.verticalCenter; implicitWidth: 40; implicitHeight: 40; leftPadding: 0; rightPadding: 0; text: "‹"; Accessible.name: "Previous week"; onClicked: root.shiftWeek(-7) }
                    AppButton { anchors.verticalCenter: parent.verticalCenter; implicitWidth: 40; implicitHeight: 40; leftPadding: 0; rightPadding: 0; text: "›"; Accessible.name: "Next week"; onClicked: root.shiftWeek(7) }
                }
            }
            Item { Layout.fillWidth: true }
            Row {
                Layout.alignment: Qt.AlignBottom
                spacing: 12
                AppButton { kind: "secondary"; text: "View venues"; onClicked: root.navigate("venues") }
                AppButton { kind: "primary"; text: "+ New event"; onClicked: newEvent.openFor(root.day) }
            }
        }

        // KPIs
        Item { width: 1; height: 26 }
        Rectangle { x: Theme.gutter; width: parent.width - 2 * Theme.gutter; height: 1; color: Theme.line }
        Row {
            x: Theme.gutter
            Repeater {
                model: [
                    ["SEATS SOLD · ON SALE", root.totals.seatsSold + "", " / " + root.totals.capacityOnSale, root.totals.percent + "% · " + root.totals.eventsOnSale + " events on sale", Theme.ink],
                    ["CONFIRMED VALUE", root.totals.valueText, "", "Cancelled bookings excluded", Theme.ink],
                    ["THIS WEEK", root.weekEvents.length + (root.weekEvents.length === 1 ? " event" : " events"), "", app.venues.length + " venues · " + (root.totals.drafts ? root.totals.drafts + " draft" + (root.totals.drafts > 1 ? "s" : "") : "all on sale"), Theme.ink],
                    ["SCHEDULE CONFLICTS", root.totals.conflicts + "", "", root.conflict ? root.conflict.venueName + " · " + root.conflict.dateText + " " + root.conflict.overlapText : "All venues clear", root.totals.conflicts ? "#FF8A7E" : Theme.ok]
                ]
                Item {
                    width: (root.availableWidth - 2 * Theme.gutter) / 4; height: 124
                    Rectangle { visible: index > 0; width: 1; height: parent.height; color: Theme.lineSoft }
                    Column {
                        x: index > 0 ? 24 : 0; y: 20; spacing: 6
                        Text { text: modelData[0]; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: index === 3 ? modelData[4] : Theme.muted }
                        Row {
                            Text { text: modelData[1]; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 48; color: modelData[4] }
                            Text { anchors.baseline: parent.children[0].baseline; text: modelData[2]; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 24; color: Theme.dim }
                        }
                        Text { text: modelData[3]; font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted }
                    }
                }
            }
        }
        Rectangle { x: Theme.gutter; width: parent.width - 2 * Theme.gutter; height: 1; color: Theme.line }

        RowLayout {
            width: parent.width
            spacing: 0

            Column {
                id: main
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                leftPadding: Theme.gutter; rightPadding: 40; topPadding: 30; bottomPadding: 48
                spacing: 34
                readonly property real inner: width - leftPadding - rightPadding

                // ---------------- timeline
                Column {
                    width: main.inner
                    spacing: 16
                    Column {
                        width: parent.width
                        spacing: 14
                        Column {
                            Text { text: "VENUE TIMELINE"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 34; color: Theme.ink }
                            Text { text: "Same venue + overlapping time = conflict. Different venues may run at the same time."; font.family: Theme.body; font.pixelSize: 14; color: Theme.muted }
                        }
                        Row {
                            spacing: 4
                            Repeater {
                                model: root.days
                                Item {
                                    readonly property bool on: root.day === modelData.date
                                    width: 74; height: 62
                                    activeFocusOnTab: true
                                    Accessible.role: Accessible.PageTab
                                    Accessible.name: modelData.label + ", " + modelData.count + " events" + (modelData.conflict ? ", conflict" : "")
                                    Keys.onReturnPressed: root.day = modelData.date
                                    Rectangle { width: parent.width; height: 2; color: parent.on ? Theme.amber : Theme.line }
                                    Column {
                                        x: 10; y: 8; spacing: 2
                                        Text { text: modelData.weekday; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1; color: parent.parent.on ? Theme.ink : Theme.muted }
                                        Text { text: modelData.day; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 24; color: parent.parent.on ? Theme.ink : Theme.muted }
                                        Text { text: modelData.conflict ? "⚠ " + modelData.count + " EVENTS" : modelData.count ? modelData.count + (modelData.count > 1 ? " EVENTS" : " EVENT") : "—"
                                               font.family: Theme.mono; font.pixelSize: 9; color: modelData.conflict ? "#FF8A7E" : Theme.dim }
                                    }
                                    Rectangle { anchors.fill: parent; color: "transparent"; border.color: Theme.amber; border.width: 2; visible: parent.activeFocus }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.day = modelData.date }
                                }
                            }
                        }
                    }

                    // hour ruler
                    Item {
                        width: parent.width; height: 22
                        Repeater {
                            model: Math.round((root.t1 - root.t0) / 60) + 1
                            Text {
                                readonly property real track: main.inner - 190
                                x: 190 + track * index * 60 / (root.t1 - root.t0) - width / 2
                                text: app.timeText(root.t0 + index * 60)
                                font.family: Theme.mono; font.pixelSize: 11; color: Theme.dim
                            }
                        }
                    }
                    Column {
                        width: parent.width
                        Repeater {
                            model: root.tl.venues
                            Item {
                                id: lane
                                readonly property var venue: modelData
                                readonly property real track: main.inner - 190
                                function px(m) { return track * (m - root.t0) / (root.t1 - root.t0) }
                                width: main.inner; height: venue.lanes * 68 + 12 + (venue.overlaps.length ? 24 : 0)
                                Rectangle { width: parent.width; height: 1; color: Theme.line }
                                Column {
                                    y: 14; width: 180; spacing: 4
                                    Text { text: lane.venue.name; font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 15; color: Theme.ink; width: 176; elide: Text.ElideRight }
                                    Text { text: lane.venue.capacity + " SEATS"; font.family: Theme.mono; font.pixelSize: 11; color: Theme.dim }
                                    Text { visible: lane.venue.overlaps.length > 0; text: "⚠ CONFLICT"; font.family: Theme.mono; font.pixelSize: 11; color: "#FF8A7E" }
                                }
                                Item {
                                    x: 190; width: lane.track; height: parent.height
                                    clip: true
                                    Repeater {       // hour grid
                                        model: Math.round((root.t1 - root.t0) / 60) + 1
                                        Rectangle { x: lane.track * index * 60 / (root.t1 - root.t0); width: 1; height: parent.height; color: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.06) }
                                    }
                                    Text { visible: lane.venue.blocks.length === 0 && !(root.fix && root.fix.venueId === lane.venue.id && root.conflict && root.conflict.date === root.day)
                                           x: 12; y: 30; text: "No events · available all day"; font.family: Theme.mono; font.pixelSize: 12; color: "#5E5951" }
                                    Repeater {       // overlap hatch (drawn over the blocks)
                                        model: lane.venue.overlaps
                                        Item {
                                            z: 2
                                            x: lane.px(modelData.start); width: lane.px(modelData.end) - lane.px(modelData.start); height: lane.height
                                            Canvas {
                                                anchors.fill: parent
                                                onPaint: {
                                                    const c = getContext("2d")
                                                    c.reset()
                                                    c.fillStyle = "rgba(255,107,94,0.10)"; c.fillRect(0, 0, width, height)
                                                    c.strokeStyle = "rgba(255,107,94,0.40)"; c.lineWidth = 2
                                                    for (let i = -height; i < width; i += 9) { c.beginPath(); c.moveTo(i, height); c.lineTo(i + height, 0); c.stroke() }
                                                }
                                            }
                                            Rectangle { width: 1; height: parent.height; color: Theme.danger }
                                            Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: Theme.danger }
                                            Rectangle { x: 4; y: parent.height - 20; width: ovl.implicitWidth + 8; height: 16; color: Theme.bg
                                                        Text { id: ovl; x: 4; anchors.verticalCenter: parent.verticalCenter; text: modelData.minutes + " MIN OVERLAP"; font.family: Theme.mono; font.pixelSize: 10; color: "#FFD0CA" } }
                                        }
                                    }
                                    Repeater {       // event blocks
                                        model: lane.venue.blocks
                                        Rectangle {
                                            x: lane.px(modelData.start); y: 8 + modelData.lane * 68
                                            width: lane.px(modelData.end) - lane.px(modelData.start); height: 60
                                            radius: 4; clip: true
                                            color: Theme.look(modelData.eventId, modelData.title, modelData.category).block
                                            Rectangle { width: 3; height: parent.height; color: modelData.conflict ? Theme.danger : Theme.look(modelData.eventId, modelData.title, modelData.category).edge }
                                            Column {
                                                x: 12; y: 8; width: parent.width - 20; spacing: 8
                                                Text { width: parent.width; text: modelData.title; elide: Text.ElideRight; font.family: Theme.body; font.weight: Font.Bold; font.pixelSize: 13; color: Theme.ink }
                                                RowLayout {
                                                    width: parent.width
                                                    Text { text: modelData.timeText; font.family: Theme.mono; font.pixelSize: 11; color: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.8) }
                                                    Item { Layout.fillWidth: true }
                                                    Text { text: modelData.occupancy; font.family: Theme.mono; font.pixelSize: 11; color: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.8) }
                                                }
                                            }
                                            Behavior on x { NumberAnimation { duration: Theme.slide; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                    Rectangle {      // preview of the selected fix
                                        id: preview
                                        readonly property bool show: root.fix !== null && root.conflict !== null && root.conflict.date === root.day && root.fix.venueId === lane.venue.id
                                        visible: show
                                        x: show ? lane.px(root.fix.start) : 0
                                        y: 8
                                        width: show ? lane.px(root.fix.end) - lane.px(root.fix.start) : 0; height: 60
                                        radius: 4
                                        color: Qt.rgba(245 / 255, 181 / 255, 68 / 255, 0.07)
                                        border.color: Theme.amber; border.width: 1.5
                                        Column {
                                            x: 10; y: 8; spacing: 8
                                            Text { text: "PREVIEW · " + (preview.show ? Theme.shortTitle(app.event(root.fix.eventId)).toUpperCase() : ""); font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1; color: "#FFE2A6" }
                                            Text { text: preview.show ? root.fix.timeText : ""; font.family: Theme.mono; font.pixelSize: 11; color: "#FFE2A6" }
                                        }
                                        opacity: preview.show ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 300 } }
                                    }
                                    Rectangle {      // now
                                        visible: root.day === root.today
                                        readonly property date now: new Date()
                                        x: lane.px(now.getHours() * 60 + now.getMinutes()); width: 1; height: parent.height
                                        color: Theme.amber
                                    }
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: Theme.line }
                    }
                    Flow {
                        x: 190; width: parent.width - 190
                        spacing: 26
                        Row { spacing: 8; Rectangle { width: 20; height: 12; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 107 / 255, 94 / 255, 0.3); border.color: Theme.danger }
                              Text { text: "Overlap in one venue — blocks publishing"; font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted } }
                        Row { spacing: 8; Rectangle { width: 20; height: 12; anchors.verticalCenter: parent.verticalCenter; color: "transparent"; border.color: Theme.amber }
                              Text { text: "Preview of the selected fix"; font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted } }
                        Text { text: "Back-to-back is fine: an event may start the minute another ends"; font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted }
                    }
                }

                // ---------------- events table
                Column {
                    width: main.inner
                    Text { bottomPadding: 10; text: "EVENTS"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 34; color: Theme.ink }
                    RowLayout {
                        width: parent.width; height: 32
                        Repeater {
                            model: [["EVENT", 0], ["WHEN · WHERE", 220], ["OCCUPANCY", 140], ["VALUE", 100], ["STATUS", 165]]
                            Text { Layout.fillWidth: modelData[1] === 0; Layout.preferredWidth: modelData[1] || 220; text: modelData[0]; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: Theme.muted }
                        }
                    }
                    Text {
                        visible: root.sortedEvents.length === 0
                        topPadding: 18; width: main.inner; wrapMode: Text.WordWrap
                        text: "No events yet. Use “+ New event” to add your first one — it starts as a draft, then publish it to put it on sale."
                        font.family: Theme.body; font.pixelSize: 16; color: "#C9C2B6"
                    }
                    Repeater {
                        model: root.sortedEvents
                        Column {
                            width: main.inner
                            Rectangle { width: parent.width; height: 1; color: Theme.lineSoft }
                            RowLayout {
                                width: parent.width; height: 70
                                readonly property string status: modelData.hasConflict ? "Conflict" : modelData.onSale ? "On sale" : "Ready"
                                readonly property color stColor: modelData.hasConflict ? "#FF8A7E" : modelData.onSale ? Theme.ok : Theme.amber
                                Row {
                                    id: evCell
                                    Layout.fillWidth: true; Layout.minimumWidth: 200
                                    spacing: 12
                                    EventArt { width: 34; height: 46; eventId: modelData.id; radius: 3 }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: evCell.width - 46
                                        Text { width: parent.width; elide: Text.ElideRight; text: modelData.title; font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 14; color: Theme.ink }
                                        Text { text: modelData.id + " · " + modelData.category; font.family: Theme.mono; font.pixelSize: 11; color: Theme.dim }
                                    }
                                }
                                Column {
                                    Layout.preferredWidth: 220
                                    spacing: 4
                                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.dayLabel + " · " + modelData.timeRange; font.family: Theme.mono; font.pixelSize: 12; color: Theme.ink }
                                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.venueName; font.family: Theme.body; font.pixelSize: 13; color: "#C9C2B6" }
                                }
                                Column {
                                    Layout.preferredWidth: 140
                                    spacing: 6
                                    Rectangle { width: 130; height: 4; color: "#2A2723"
                                                Rectangle { height: 4; width: parent.width * modelData.booked / Math.max(1, modelData.capacity); color: modelData.booked / Math.max(1, modelData.capacity) > 0.7 ? Theme.amber : Theme.ink } }
                                    Text { text: modelData.onSale ? modelData.booked + " / " + modelData.capacity + " · " + Math.round(100 * modelData.booked / Math.max(1, modelData.capacity)) + "%" : "Not on sale"
                                           font.family: Theme.mono; font.pixelSize: 11; color: Theme.muted }
                                }
                                Text { Layout.preferredWidth: 100; text: modelData.value ? modelData.valueText : "—"; font.family: Theme.mono; font.pixelSize: 13; color: Theme.ink }
                                Row {
                                    Layout.preferredWidth: 165
                                    spacing: 8
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: stText.implicitWidth + 20; height: 26; radius: 13
                                        color: "transparent"; border.color: parent.parent.stColor
                                        Text { id: stText; anchors.centerIn: parent; text: parent.parent.parent.status.toUpperCase(); font.family: Theme.mono; font.pixelSize: 11; color: parent.parent.parent.stColor }
                                    }
                                    AppButton { visible: !modelData.onSale && !modelData.hasConflict; implicitHeight: 30; leftPadding: 10; rightPadding: 10; textSize: 12
                                                kind: "outlineAmber"; text: "Publish"; Accessible.name: "Publish " + modelData.title; onClicked: root.publish(modelData.id) }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- side panel
            Rectangle {
                Layout.preferredWidth: 440
                Layout.fillHeight: true
                Layout.minimumHeight: side.implicitHeight + 60
                color: Theme.surface
                Rectangle { width: 1; height: parent.height; color: Theme.lineSoft }
                Column {
                    id: side
                    x: 30; y: 30; width: parent.width - 60
                    spacing: 26

                    Rectangle {
                        visible: root.notice !== ""
                        width: parent.width; height: noticeText.implicitHeight + 24
                        color: root.noticeOk ? Qt.rgba(127 / 255, 214 / 255, 164 / 255, 0.08) : Qt.rgba(1, 107 / 255, 94 / 255, 0.08)
                        Rectangle { width: 2; height: parent.height; color: root.noticeOk ? Theme.ok : Theme.danger }
                        Text { id: noticeText; x: 16; y: 12; width: parent.width - 28; wrapMode: Text.WordWrap; text: root.notice
                               font.family: Theme.body; font.pixelSize: 14; color: root.noticeOk ? "#BFF0D2" : "#FFC2BB" }
                        Accessible.role: Accessible.AlertMessage
                        Accessible.name: root.notice
                    }

                    // conflict
                    Column {
                        visible: root.conflict !== null
                        width: parent.width
                        spacing: 16
                        Column {
                            Text { text: "⚠ " + root.conflicts.length + (root.conflicts.length === 1 ? " CONFLICT BLOCKS PUBLISHING" : " CONFLICTS BLOCK PUBLISHING"); font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: "#FF8A7E" }
                            Text { topPadding: 8; width: side.width; wrapMode: Text.WordWrap
                                   text: root.conflict ? (root.conflict.venueName + " · " + root.conflict.dateText).toUpperCase() : ""
                                   font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 34; lineHeight: 0.95; color: Theme.ink }
                        }
                        Rectangle {
                            width: parent.width; height: pair.implicitHeight
                            radius: 4; color: "transparent"; border.color: Theme.line
                            Column {
                                id: pair
                                width: parent.width
                                Repeater {
                                    model: root.conflict ? [root.conflict.first, root.conflict.second] : []
                                    Column {
                                        width: pair.width
                                        Rectangle { visible: index > 0; width: parent.width; height: 1; color: Theme.line }
                                        RowLayout {
                                            width: parent.width; height: 64
                                            Column {
                                                Layout.leftMargin: 14; Layout.fillWidth: true
                                                Text { text: modelData.title; font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 14; color: Theme.ink }
                                                Text { text: modelData.timeRange + " · " + modelData.status + " · " + modelData.booked + " BOOKED"; font.family: Theme.mono; font.pixelSize: 11; color: Theme.muted }
                                            }
                                            Text { Layout.rightMargin: 14; text: modelData.locked ? "LOCKED" : root.conflict.minutes + " MIN OVERLAP"
                                                   font.family: Theme.mono; font.pixelSize: 11; color: modelData.locked ? Theme.dim : "#FF8A7E" }
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            text: root.conflict && root.conflict.fixes.length
                                  ? "Events with bookings keep their time and venue. Pick a fix — the dashed preview on the timeline shows where the event would land before you apply it."
                                  : "Both events already have bookings, so SeatCraft can't move either automatically. Contact the organisers to agree a change."
                            font.family: Theme.body; font.pixelSize: 13; lineHeight: 1.3; color: "#C9C2B6"
                        }
                        Repeater {
                            model: root.conflict ? root.conflict.fixes : []
                            Rectangle {
                                readonly property bool on: root.fixIndex === index
                                width: side.width; height: fixText.implicitHeight + 28
                                radius: 4
                                color: on ? Qt.rgba(245 / 255, 181 / 255, 68 / 255, 0.06) : "transparent"
                                border.color: on ? Theme.amber : fixHover.hovered ? Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.4) : Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.16)
                                activeFocusOnTab: true
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData.description
                                Accessible.checked: on
                                Keys.onReturnPressed: root.fixIndex = index
                                Keys.onSpacePressed: root.fixIndex = index
                                Rectangle { x: 14; y: 16; width: 16; height: 16; radius: 8; color: "transparent"; border.color: parent.on ? Theme.amber : Theme.muted; border.width: 1.5
                                            Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.amber; visible: parent.parent.on } }
                                Column {
                                    id: fixText
                                    x: 42; y: 14; width: parent.width - 56; spacing: 4
                                    Text { width: parent.width; wrapMode: Text.WordWrap
                                           text: (modelData.venueId === root.conflict.venueId ? "Same venue · " : "New venue · ") + modelData.timeText + (index === 0 ? "   RECOMMENDED" : "")
                                           font.family: Theme.mono; font.pixelSize: 11; color: index === 0 ? Theme.amber : Theme.muted }
                                    Text { width: parent.width; wrapMode: Text.WordWrap; text: modelData.description; font.family: Theme.body; font.pixelSize: 14; color: Theme.ink }
                                }
                                Rectangle { anchors.fill: parent; anchors.margins: -3; radius: 6; color: "transparent"; border.color: Theme.amber; border.width: 2; visible: parent.activeFocus }
                                HoverHandler { id: fixHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { root.fixIndex = index; root.day = root.conflict.date } }
                            }
                        }
                        AppButton { visible: root.fix !== null; width: parent.width; implicitHeight: 52; kind: "primary"; text: "Apply & re-check schedule"; onClicked: root.applyFix() }
                    }

                    // clear schedule + drafts
                    Column {
                        visible: root.conflict === null
                        width: parent.width
                        spacing: 12
                        Text { text: "✓ NO CONFLICTS"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.6; color: Theme.ok }
                        Text { text: "SCHEDULE IS CLEAR"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 34; color: Theme.ink }
                        Text { width: parent.width; wrapMode: Text.WordWrap
                               text: root.totals.drafts ? "Draft events are ready to publish. Publishing puts them on sale in Discover." : "Every event is on sale and no venue is double-booked."
                               font.family: Theme.body; font.pixelSize: 14; color: "#C9C2B6" }
                        Repeater {
                            model: app.events.filter((e) => !e.onSale)
                            AppButton { width: side.width; kind: "primary"; text: "Publish " + modelData.title; onClicked: root.publish(modelData.id) }
                        }
                    }

                    Column {
                        width: parent.width
                        Rectangle { width: parent.width; height: 1; color: Theme.line }
                        Text { topPadding: 20; bottomPadding: 6; text: "LATEST BOOKINGS"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 26; color: Theme.ink }
                        Repeater {
                            model: (app.revision, app.recentBookings(5))
                            Column {
                                width: side.width
                                GridLayout {
                                    width: parent.width; columns: 2; rowSpacing: 2
                                    Text { Layout.topMargin: 12; text: modelData.customer + (modelData.confirmed ? "" : " · cancelled"); font.family: Theme.body; font.weight: Font.DemiBold; font.pixelSize: 14; color: modelData.confirmed ? Theme.ink : Theme.muted; Layout.fillWidth: true }
                                    Text { Layout.topMargin: 12; text: (modelData.confirmed ? "" : "−") + modelData.totalText; font.family: Theme.mono; font.pixelSize: 12; color: modelData.confirmed ? Theme.ink : Theme.muted }
                                    Text { Layout.bottomMargin: 12; Layout.columnSpan: 2; text: modelData.eventId + " · " + modelData.bookingId + " · " + modelData.seats; font.family: Theme.mono; font.pixelSize: 11; color: Theme.muted }
                                }
                                Rectangle { width: parent.width; height: 1; color: Theme.lineSoft }
                            }
                        }
                    }
                }
            }
        }
    }
}
