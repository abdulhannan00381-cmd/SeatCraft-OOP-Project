import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 1440; height: 900
    minimumWidth: 1280; minimumHeight: 760
    visible: true
    title: "SeatCraft — Box office" + (app.demo ? "  (Demo data)" : "")
    color: Theme.bg

    property string page: "discover"           // discover | seats | bookings | venues | organizer
    property string eventId: ""                 // event shown on the seat page
    property string ticketEvent: ""
    property string ticketBooking: ""

    function openSeats(id) { eventId = id; page = "seats" }
    function openTicket(e, b) { ticketEvent = e; ticketBooking = b; page = "bookings" }

    readonly property var pageNames: ["discover", "seats", "bookings", "venues", "organizer"]

    LoadErrorPage {
        anchors.fill: parent
        visible: app.loadError !== ""
    }

    ColumnLayout {
        id: frameRoot
        anchors.fill: parent
        spacing: 0
        visible: app.loadError === ""

        TopBar {
            Layout.fillWidth: true
            current: win.page
            onNavigate: (p) => win.page = p
        }
        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.pageNames.indexOf(win.page)

            DiscoverPage {
                id: discoverPage
                onOpenSeats: (id) => win.openSeats(id)
                onNavigate: (p) => win.page = p
            }
            SeatPage {
                id: seatPage
                eventId: win.eventId
                onEventChosen: (id) => win.eventId = id
                onOpenTicket: (e, b) => win.openTicket(e, b)
                onDownloadTicket: (e, b) => { win.openTicket(e, b); bookingsPage.autoDownload = true }
                onBack: win.page = "discover"
            }
            BookingsPage {
                id: bookingsPage
                eventId: win.ticketEvent
                bookingId: win.ticketBooking
                onSelect: (e, b) => { win.ticketEvent = e; win.ticketBooking = b }
                onBookMore: (e) => win.openSeats(e)
            }
            VenuesPage {
                id: venuesPage
                onOpenSeats: (id) => win.openSeats(id)
            }
            OrganizerPage {
                id: organizerPage
                onNavigate: (p) => win.page = p
            }
        }
    }

    // ---- screenshot mode (--screenshots <dir>): renders each screen and quits ----
    property int shotIndex: -1
    property bool shotReady: false
    // --film: capture the whole window at 2x for every step of the showcase film (capture only).
    readonly property bool film: Qt.application.arguments.indexOf("--film") >= 0
    function sc(p, y) { pageItems[p].contentItem.contentY = y }
    function findField(item, hint) {
        if (item.placeholderText === hint) return item
        for (let i = 0; i < item.children.length; i++) { const f = findField(item.children[i], hint); if (f) return f }
        return null
    }
    function typeSearch(t) { const f = findField(bookingsPage.content, "e.g. BKG-0013 or Ayesha"); if (f) f.text = t; bookingsPage.query = t }
    readonly property var filmShots: [
        { name: "f01-discover", page: "discover", act: () => sc("discover", 0) },
        { name: "f01b-discover-full", page: "discover", full: true },
        { name: "f02a-discover-day-full", page: "discover", full: true, act: () => discoverPage.day = "2026-11-12" },
        { name: "f02-discover-filter", page: "discover", act: () => { discoverPage.cat = "Talks"; discoverPage.day = "2026-11-12"; sc("discover", 520) } },
        { name: "f02b-discover-filter-full", page: "discover", full: true },
        { name: "f03-seats-open", page: "seats", event: "EVT01", act: () => { discoverPage.cat = "All"; discoverPage.day = ""; seatPage.resetFlow(); sc("seats", 0) } },
        { name: "f04-seats-c5", page: "seats", act: () => seatPage.toggle("C5") },
        { name: "f05-seats-best", page: "seats", act: () => { seatPage.resetFlow(); seatPage.findBest() } },
        { name: "f06-details-empty", page: "seats", act: () => { seatPage.toDetails(); sc("seats", 330) } },
        { name: "f06b-seats-full", page: "seats", full: true },
        { name: "f07-details-a", page: "seats", act: () => seatPage.customerName = "Ayes" },
        { name: "f08-details-b", page: "seats", act: () => seatPage.customerName = "Ayesha Kh" },
        { name: "f09-details-full", page: "seats", act: () => seatPage.customerName = "Ayesha Khan" },
        { name: "f10-confirmed", page: "seats", act: () => { seatPage.confirm(); sc("seats", 0) } },
        { name: "f11-ticket", page: "bookings", act: () => { win.openTicket("EVT01", seatPage.done.bookingId || "BKG-0013"); sc("bookings", 0) } },
        { name: "f12-ticket-saved", page: "bookings", act: () => { bookingsPage.downloadTicket(); sc("bookings", 120) } },
        { name: "f13a-search", page: "bookings", act: () => { bookingsPage.flash = ""; bookingsPage.savedFolder = ""; sc("bookings", 0); typeSearch("BKG") } },
        { name: "f13-search", page: "bookings", act: () => typeSearch("BKG-0013") },
        { name: "f14-cancel-ask", page: "bookings", act: () => { bookingsPage.confirmOpen = true; sc("bookings", 420) } },
        { name: "f14b-bookings-full", page: "bookings", full: true },
        { name: "f15-cancelled", page: "bookings", act: () => { bookingsPage.doCancel(); sc("bookings", 0) } },
        { name: "f15b-cancelled-full", page: "bookings", full: true },
        { name: "f16-seats-free", page: "seats", event: "EVT01", act: () => { seatPage.resetFlow(); sc("seats", 0) } },
        { name: "f17-organizer-clash", page: "organizer", act: () => sc("organizer", 0) },
        { name: "f17b-organizer-full", page: "organizer", full: true },
        { name: "f18-organizer-fixed", page: "organizer", act: () => organizerPage.applyFix() },
        { name: "f18b-organizer-fixed-full", page: "organizer", full: true },
        { name: "f19-organizer-published", page: "organizer", act: () => organizerPage.publish("EVT02") },
        { name: "f19b-organizer-published-full", page: "organizer", full: true },
        { name: "f20-venues", page: "venues", act: () => sc("venues", 0) },
        { name: "f20b-venues-full", page: "venues", full: true },
        { name: "f21-seats-eh", page: "seats", event: "EVT03", act: () => { seatPage.resetFlow(); sc("seats", 0) } },
        { name: "f22-seats-oa", page: "seats", event: "EVT04", act: () => { seatPage.resetFlow(); sc("seats", 0) } }
    ]
    readonly property var shots: film ? filmShots : app.demo ? [
        { name: "01-discover", page: "discover" },
        { name: "02-seats-main-auditorium", page: "seats", event: "EVT01", action: "best" },
        { name: "02b-seats-confirmed", page: "seats", event: "EVT01", action: "confirm" },
        { name: "03-seats-engineering-hall", page: "seats", event: "EVT03" },
        { name: "04-seats-amphitheatre", page: "seats", event: "EVT04" },
        { name: "05-venues", page: "venues" },
        { name: "06-bookings", page: "bookings" },
        { name: "06b-ticket-downloaded", page: "bookings", action: "download" },
        { name: "07-organizer", page: "organizer" },
        { name: "08-organizer-after-fix", page: "organizer", action: "applyFix" },
        { name: "09-new-events-discover", page: "discover", action: "addEvents" },
        { name: "10-new-events-organizer", page: "organizer" }
    ] : [
        { name: "p1-discover-empty", page: "discover" },
        { name: "p2-organizer-empty", page: "organizer" },
        { name: "p3-seats-empty", page: "seats" },
        { name: "p4-bookings-empty", page: "bookings" },
        { name: "p5-venues", page: "venues" },
        { name: "p6-discover-after-first-events", page: "discover", action: "addEvents" }
    ]

    // Used by screenshot mode to prove every new event gets its own artwork.
    function addSampleNewEvents() {
        const list = [
            ["Inter-University Cricket Final", "Sports", "2026-11-19", "14:00", "17:00", "OA", 800, 400],
            ["Spring Film Screening: Dune", "Film", "2026-11-19", "18:00", "20:30", "MA", 700, 400],
            ["Final Year Art Exhibition", "Art", "2026-11-19", "11:00", "15:00", "EH", 400, 200],
            ["Debate Championship 2026", "Talks", "2026-11-20", "14:00", "17:00", "MA", 600, 300],
            ["The Comedy Improv Night", "Theatre", "2026-11-20", "21:15", "23:00", "MA", 900, 500],
            ["AI & Robotics Hackathon Demo Day", "Tech", "2026-11-21", "10:00", "13:00", "EH", 600, 300],
            ["Campus Food Festival", "Festival", "2026-11-21", "16:00", "21:00", "OA", 500, 300],
            ["Classical Music Recital", "Music", "2026-11-21", "18:00", "20:00", "MA", 900, 500]
        ]
        for (const f of list) {
            const r = app.createEvent({ title: f[0], category: f[1], date: f[2], start: f[3], end: f[4], venueId: f[5], vipPrice: f[6], regularPrice: f[7] })
            if (r.ok) app.publishEvent(r.eventId)
            else console.warn("createEvent failed:", f[0], r.message)
        }
    }
    readonly property var pageItems: ({ discover: discoverPage, seats: seatPage, bookings: bookingsPage,
                                        venues: venuesPage, organizer: organizerPage })

    Timer { id: quitTimer; interval: 2500; onTriggered: Qt.quit() }
    Timer {
        id: shotTimer
        interval: 1200
        running: screenshotDir !== ""
        repeat: true
        Component.onCompleted: if (win.film) { win.width = 1600; win.height = 900 }
        onTriggered: {
            // Phase 1: navigate (and run the scripted action). Phase 2, one tick later: capture.
            if (win.shotReady) {
                const shot = win.shots[win.shotIndex]
                if (win.film) {
                    const item = shot.full ? win.pageItems[shot.page].content : frameRoot
                    item.grabToImage((r) => r.saveToFile(screenshotDir + "/" + shot.name + ".png"),
                                     Qt.size(item.width * 2, item.height * 2))
                } else {
                    const full = win.pageItems[shot.page].content
                    full.grabToImage((r) => r.saveToFile(screenshotDir + "/" + shot.name + ".png"))
                }
                win.shotReady = false
                return
            }
            win.shotIndex++
            if (win.shotIndex >= win.shots.length) { stop(); quitTimer.start(); return }
            const next = win.shots[win.shotIndex]
            if (next.event) win.eventId = next.event
            win.page = next.page
            if (next.act) next.act()
            if (next.action === "best") seatPage.findBest()
            if (next.action === "applyFix") organizerPage.applyFix()
            if (next.action === "addEvents") win.addSampleNewEvents()
            if (next.action === "download") bookingsPage.downloadTicket()
            if (next.action === "confirm") {
                seatPage.findBest()
                seatPage.toDetails()
                seatPage.customerName = "Ayesha Khan"
                seatPage.confirm()
            }
            win.shotReady = true
        }
    }
}
