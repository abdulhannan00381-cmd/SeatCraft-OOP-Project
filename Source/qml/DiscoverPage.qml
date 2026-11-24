import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// 01 · Discover — featured event, quick book, calendar, posters, venues.
ScrollView {
    id: root
    signal openSeats(string eventId)
    signal navigate(string page)
    property alias content: body

    contentWidth: availableWidth
    clip: true

    property string cat: "All"
    property string day: ""
    property int qty: 2

    readonly property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")
    readonly property var onSale: app.events.filter((e) => e.onSale)
    readonly property var bySoonest: onSale.slice().sort((a, b) => a.date === b.date ? a.start - b.start : (a.date < b.date ? -1 : 1))
    // Featured = the next event on sale (or the earliest one if all are in the past).
    readonly property var featured: bySoonest.filter((e) => e.date >= today)[0] || bySoonest[0] ||
        ({ id: "", title: "", category: "", date: "", displayDate: "", dayLabel: "", timeRange: "", venueId: "", venueName: "",
           vipPriceText: "", regularPriceText: "", remaining: 0, capacity: 0 })
    readonly property bool hasEvents: featured.id !== ""
    readonly property string featuredId: hasEvents ? featured.id : ""
    readonly property var best: hasEvents ? (app.revision, app.bestTogether(featuredId, qty, "Any")) : []
    readonly property var bestPrice: hasEvents ? app.priceSelection(featuredId, best) : ({})
    readonly property var shown: onSale.filter((e) => (cat === "All" || e.category === cat) && (!day || e.date === day))
    readonly property var sameDay: hasEvents ? onSale.filter((e) => e.date === featured.date && e.id !== featuredId) : []

    // Hero title: short title, with a trailing year shown as an outlined second line.
    readonly property var titleWords: hasEvents ? Theme.shortTitle(featured).toUpperCase().split(" ") : []
    readonly property bool yearLine: titleWords.length > 1 && /^\d{4}$/.test(titleWords[titleWords.length - 1])
    readonly property string titleLine1: yearLine ? titleWords.slice(0, -1).join(" ") : titleWords.join(" ")
    readonly property string titleLine2: yearLine ? titleWords[titleWords.length - 1] : ""

    // Calendar: two weeks from the Monday of the featured event's week (or this week).
    function mondayOf(ymd) {
        const d = new Date(ymd + "T00:00:00")
        d.setDate(d.getDate() - ((d.getDay() + 6) % 7))
        return Qt.formatDate(d, "yyyy-MM-dd")
    }
    readonly property var calendarDays: (app.revision, app.calendar(mondayOf(hasEvents ? featured.date : today), 14))
    readonly property string calendarTitle: calendarDays.length
        ? (calendarDays[0].label.slice(4) + " – " + calendarDays[13].label.slice(4)).toUpperCase() : ""

    Column {
        id: body
        width: root.availableWidth
        bottomPadding: 56

        // ------------------------------------------------------------ empty programme
        Item {
            visible: !root.hasEvents
            width: parent.width; height: 560
            Column {
                anchors.left: parent.left; anchors.leftMargin: Theme.gutter
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(760, parent.width - 2 * Theme.gutter)
                spacing: 18
                Text { text: "WELCOME TO SEATCRAFT"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.stageEdge }
                Text { width: parent.width; text: "NO EVENTS ON SALE YET"; wrapMode: Text.WordWrap
                       font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 110; lineHeight: 0.85; color: Theme.ink }
                Text { width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.3
                       text: "Create your first event in the Organizer, publish it, and it will appear here ready for booking. Your three venues are already set up."
                       font.family: Theme.body; font.pixelSize: 18; color: Theme.ink2 }
                Row {
                    topPadding: 10; spacing: 14
                    AppButton { kind: "primary"; text: "Go to Organizer  →"; onClicked: root.navigate("organizer") }
                    AppButton { kind: "secondary"; text: "See the venues"; onClicked: root.navigate("venues") }
                }
            }
        }

        // ------------------------------------------------------------ hero
        Item {
            visible: root.hasEvents
            width: parent.width
            height: visible ? 640 : 0

            Image {
                visible: root.hasEvents && Theme.hasArt(root.featuredId, root.featured.title) && root.featuredId === "EVT01"
                anchors.fill: parent
                source: visible ? "qrc:/qt/qml/SeatCraft/assets/art/hero_tt.svg" : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 2880
                asynchronous: true
            }
            EventArt {      // any other featured event: its poster art fills the right side
                visible: root.hasEvents && !(Theme.hasArt(root.featuredId, root.featured.title) && root.featuredId === "EVT01")
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: parent.width * 0.62
                eventId: root.featuredId
                showText: false
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.bg }
                    GradientStop { position: 0.30; color: Qt.rgba(11 / 255, 10 / 255, 9 / 255, 0.88) }
                    GradientStop { position: 0.64; color: "transparent" }
                }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.6; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.bg }
                }
            }

            Column {
                anchors.left: parent.left; anchors.leftMargin: Theme.gutter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 52
                width: Math.min(660, parent.width * 0.5)
                spacing: 0

                Text {
                    text: root.hasEvents ? "FEATURED · " + root.featured.category.toUpperCase() + " · " + root.featured.displayDate.toUpperCase() : ""
                    font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8
                    color: Theme.stageEdge
                }
                Text {
                    topPadding: 12
                    width: parent.width
                    height: root.titleLine2 ? 128 : 240
                    text: root.titleLine1
                    wrapMode: Text.WordWrap; maximumLineCount: 2
                    fontSizeMode: Text.Fit; minimumPixelSize: 48
                    verticalAlignment: Text.AlignBottom
                    font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black
                    font.pixelSize: 140; lineHeight: 0.82
                    color: Theme.ink
                }
                Text {
                    visible: root.titleLine2 !== ""
                    text: root.titleLine2
                    font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black
                    font.pixelSize: 140; lineHeight: 0.86
                    color: Theme.bg; style: Text.Outline; styleColor: Theme.ink
                }
                Text {
                    topPadding: 18
                    width: Math.min(parent.width, 520)
                    text: Theme.blurb(root.featured) ? root.featured.title + ". " + Theme.blurb(root.featured)
                          : root.featured.category + " at " + root.featured.venueName + " — " + root.featured.displayDate + ". " + root.featured.remaining + " of " + root.featured.capacity + " seats still open."
                    wrapMode: Text.WordWrap
                    font.family: Theme.body; font.pixelSize: 17; lineHeight: 1.3
                    color: Theme.ink2
                }
                Text {
                    topPadding: 16
                    text: root.featured.timeRange + "   /   " + root.featured.venueName + "   /   VIP " + root.featured.vipPriceText + " · Regular " + root.featured.regularPriceText
                    font.family: Theme.mono; font.pixelSize: 13
                    color: Theme.ink
                }
                Row {
                    topPadding: 26
                    spacing: 14
                    AppButton { kind: "primary"; text: "Choose seats  →"; onClicked: root.openSeats(root.featuredId) }
                    AppButton { kind: "secondary"; text: "View seating plan"; onClicked: root.openSeats(root.featuredId) }
                }
            }

            // Quick book card
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: Theme.gutter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 52
                width: 336; height: qb.implicitHeight + 40
                radius: 6
                color: Qt.rgba(11 / 255, 10 / 255, 9 / 255, 0.86)
                border.color: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.14)

                Column {
                    id: qb
                    x: 20; y: 20; width: parent.width - 40
                    spacing: 12
                    RowLayout {
                        width: parent.width
                        Text { text: "QUICK BOOK"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.ink }
                        Item { Layout.fillWidth: true }
                        Text {
                            textFormat: Text.StyledText
                            text: "<font color='" + Theme.amber + "'>" + root.featured.remaining + "</font> of " + root.featured.capacity + " open"
                            font.family: Theme.mono; font.pixelSize: 12; color: Theme.ink
                        }
                    }
                    VenuePlan {
                        width: parent.width; height: width * 470 / 920
                        venueId: root.featured.venueId; eventId: root.featuredId
                        mode: "locator"; interactive: false
                        highlight: root.best
                        Accessible.role: Accessible.Graphic
                        Accessible.name: "Best " + root.qty + " seats together: " + root.best.join(", ")
                    }
                    RowLayout {
                        width: parent.width
                        Row {
                            spacing: 0
                            AppButton { implicitWidth: 36; implicitHeight: 36; leftPadding: 0; rightPadding: 0; text: "−"; Accessible.name: "Fewer seats"; onClicked: root.qty = Math.max(1, root.qty - 1) }
                            Text { width: 70; height: 36; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignHCenter
                                   text: root.qty + (root.qty === 1 ? " seat" : " seats"); font.family: Theme.mono; font.pixelSize: 13; color: Theme.ink }
                            AppButton { implicitWidth: 36; implicitHeight: 36; leftPadding: 0; rightPadding: 0; text: "+"; Accessible.name: "More seats"; onClicked: root.qty = Math.min(6, root.qty + 1) }
                        }
                        Item { Layout.fillWidth: true }
                        Column {
                            Text {
                                anchors.right: parent.right
                                text: root.best.length ? root.best[0] + (root.best.length > 1 ? "–" + root.best[root.best.length - 1] : "") : "None free"
                                font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 24
                                color: Theme.ink
                            }
                            Text {
                                anchors.right: parent.right
                                text: root.best.length && root.bestPrice.items ? (root.bestPrice.items[0].category + " · row " + root.best[0][0] + " · together") : "Try fewer seats"
                                font.family: Theme.mono; font.pixelSize: 11; color: Theme.muted
                            }
                        }
                    }
                    AppButton {
                        width: parent.width; implicitHeight: 44
                        kind: "outlineAmber"
                        enabled: root.best.length > 0
                        text: "Review best seats   " + (root.bestPrice.totalText || "") + "  →"
                        textSize: 14
                        onClicked: root.openSeats(root.featuredId)
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.line; visible: root.sameDay.length > 0 }
                    Text { visible: root.sameDay.length > 0; text: "ALSO ON " + root.featured.dayLabel.toUpperCase(); font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
                    Repeater {
                        model: root.sameDay
                        RowLayout {
                            width: qb.width
                            Text { text: modelData.title; font.family: Theme.body; font.pixelSize: 14; color: Theme.ink; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: modelData.startText + " · " + modelData.venueName.split(" ")[0]; font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------ calendar
        Item { width: 1; height: 24 }
        RowLayout {
            x: Theme.gutter; width: parent.width - 2 * Theme.gutter
            Column {
                Text { text: "CALENDAR"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
                Text { text: root.calendarTitle; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 40; color: Theme.ink }
            }
            Item { Layout.fillWidth: true }
            Row {
                spacing: 26
                Repeater {
                    model: ["All"].concat(Array.from(new Set(root.onSale.map((e) => e.category))).sort())
                    NavLink {
                        readonly property int n: modelData === "All" ? root.onSale.length : root.onSale.filter((e) => e.category === modelData).length
                        text: modelData + "  " + n
                        active: root.cat === modelData
                        onClicked: root.cat = modelData
                    }
                }
            }
        }
        Item { width: 1; height: 16 }
        Row {
            x: Theme.gutter
            readonly property real cell: (root.availableWidth - 2 * Theme.gutter) / 14
            Repeater {
                model: root.calendarDays
                Item {
                    width: parent.cell; height: 86
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label + ", " + modelData.onSale + " events"
                    Keys.onReturnPressed: root.day = root.day === modelData.date ? "" : modelData.date
                    readonly property bool on: root.day === modelData.date
                    Rectangle { width: parent.width - 2; height: 2; color: parent.on ? Theme.amber : Theme.line }
                    Column {
                        x: 12; y: 12; spacing: 4
                        Text { text: modelData.weekday; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.1; color: parent.parent.on ? Theme.ink : Theme.muted }
                        Text { text: modelData.day; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 30
                               color: modelData.onSale ? (parent.parent.on ? Theme.ink : Theme.muted) : "#5E5951" }
                        Row { spacing: 4; Repeater { model: modelData.onSale; Rectangle { width: 6; height: 6; radius: 3; color: Theme.amber } } }
                    }
                    Rectangle { anchors.fill: parent; color: "transparent"; border.color: Theme.amber; border.width: 2; visible: parent.activeFocus }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.day = root.day === modelData.date ? "" : modelData.date }
                }
            }
        }

        // ------------------------------------------------------------ posters
        Item { width: 1; height: 34 }
        RowLayout {
            x: Theme.gutter; width: parent.width - 2 * Theme.gutter
            Text { text: "NOW BOOKING"; font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 40; color: Theme.ink }
            Item { Layout.fillWidth: true }
            Text {
                text: root.shown.length + " of " + root.onSale.length + " events" + (root.day ? " · " + root.day.slice(8) + " Nov" : "") + (root.cat !== "All" ? " · " + root.cat : "")
                font.family: Theme.mono; font.pixelSize: 12; color: Theme.muted
            }
            NavLink { visible: root.cat !== "All" || root.day !== ""; text: "Clear filters"; onClicked: { root.cat = "All"; root.day = "" } }
        }
        Item { width: 1; height: 22 }
        Text {
            x: Theme.gutter
            visible: root.shown.length === 0
            text: "No events match this filter. Try another day or category."
            font.family: Theme.body; font.pixelSize: 16; color: "#C9C2B6"
        }
        Flow {
            x: Theme.gutter; width: parent.width - 2 * Theme.gutter
            spacing: 26
            readonly property real posterW: Math.max(200, (width - 4 * spacing) / 5)
            Repeater {
                model: root.shown
                Item {
                    id: poster
                    width: parent.posterW; height: art.height + info.implicitHeight + 14
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title + ", " + modelData.dayLabel + ", " + modelData.startText + ", " + modelData.venueName + ", " + modelData.remaining + " seats left"
                    Keys.onReturnPressed: root.openSeats(modelData.id)
                    EventArt {
                        id: art
                        width: parent.width; height: width * 1.5
                        eventId: modelData.id
                        radius: 6
                        y: hov.hovered ? -6 : 0
                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                    Column {
                        id: info
                        y: art.height + 14; width: parent.width; spacing: 8
                        Text { width: parent.width; text: modelData.title.toUpperCase(); wrapMode: Text.WordWrap
                               font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 24; lineHeight: 0.95; color: Theme.ink }
                        Text { text: (modelData.weekday + " " + modelData.dayNumber + " NOV · " + modelData.startText + " · " + modelData.venueName).toUpperCase()
                               width: parent.width; elide: Text.ElideRight; font.family: Theme.mono; font.pixelSize: 11; color: Theme.muted }
                        RowLayout {
                            width: parent.width
                            Text { text: modelData.category; font.family: Theme.body; font.pixelSize: 13; color: "#C9C2B6" }
                            Item { Layout.fillWidth: true }
                            Text {
                                readonly property bool low: modelData.remaining <= 10
                                text: modelData.remaining + " left" + (low ? " · selling fast" : "")
                                font.family: Theme.mono; font.pixelSize: 12; color: low ? Theme.amber : Theme.ink
                            }
                        }
                        Rectangle {
                            width: parent.width; height: 3; color: "#2A2723"
                            Rectangle { height: 3; width: parent.width * modelData.booked / Math.max(1, modelData.capacity)
                                        color: modelData.remaining <= 10 ? Theme.amber : Theme.ink }
                        }
                    }
                    Rectangle { anchors.fill: parent; anchors.margins: -6; color: "transparent"; border.color: Theme.amber; border.width: 2; radius: 8; visible: parent.activeFocus }
                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.openSeats(modelData.id) }
                }
            }
        }

        // ------------------------------------------------------------ venues strip
        Item { width: 1; height: 46 }
        Text { x: Theme.gutter; text: "VENUES"; font.family: Theme.mono; font.pixelSize: 11; font.letterSpacing: 1.8; color: Theme.muted }
        Item { width: 1; height: 14 }
        Rectangle { x: Theme.gutter; width: parent.width - 2 * Theme.gutter; height: 1; color: Theme.line }
        Row {
            x: Theme.gutter
            Repeater {
                model: app.venues
                Item {
                    width: (root.availableWidth - 2 * Theme.gutter) / 3; height: 110
                    Rectangle { visible: index > 0; width: 1; height: parent.height; color: Theme.line }
                    Column {
                        x: index > 0 ? 28 : 0; y: 22; spacing: 6
                        Text { text: modelData.name.toUpperCase(); font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.ExtraBold; font.pixelSize: 24; color: Theme.ink }
                        Text { text: (modelData.capacity + " seats · " + modelData.layout + " · VIP " + modelData.vipRowsText.replace("Rows ", "").replace("Row ", "")).toUpperCase()
                               font.family: Theme.mono; font.pixelSize: 11; color: Theme.muted }
                        Text { text: modelData.events.length ? "Next: " + modelData.events[0].title + " · " + modelData.events[0].weekday.charAt(0) + modelData.events[0].weekday.slice(1).toLowerCase() + " " + modelData.events[0].startText : "No events on sale"
                               font.family: Theme.body; font.pixelSize: 14; color: "#C9C2B6" }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.navigate("venues") }
                }
            }
        }
    }
}
