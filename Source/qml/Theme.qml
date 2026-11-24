// Design tokens from the approved Marquee design (see the engineering handoff).
pragma Singleton
import QtQuick

QtObject {
    // ---- colour ----
    readonly property color bg: "#0B0A09"
    readonly property color surface: "#14120F"
    readonly property color surface2: "#100E0C"
    readonly property color ink: "#F3EEE6"
    readonly property color ink2: "#D8D1C5"
    readonly property color muted: "#A8A196"
    readonly property color dim: "#7D776E"
    readonly property color line: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.12)
    readonly property color lineSoft: Qt.rgba(243 / 255, 238 / 255, 230 / 255, 0.07)
    readonly property color amber: "#F5B544"
    readonly property color amberDeep: "#B57C16"
    readonly property color vip: "#E9D9B8"
    readonly property color ok: "#7FD6A4"
    readonly property color danger: "#FF6B5E"
    readonly property color stageEdge: "#C9D2FF"
    readonly property color stageFill: "#2A2D60"

    // ---- type ----
    // The design fonts are used when installed; otherwise Windows' own
    // Bahnschrift (condensed), Segoe UI and Consolas stand in.
    readonly property bool designFonts: typeof hasDesignFonts !== "undefined" && hasDesignFonts
    readonly property string display: designFonts ? "Big Shoulders Display" : "Bahnschrift"
    readonly property string body: designFonts ? "Instrument Sans" : "Segoe UI"
    readonly property string mono: "Consolas"
    // Bahnschrift is a variable font: a 75% width axis gives the condensed display cut.
    readonly property var displayAxes: designFonts ? ({}) : ({ "wdth": 75 })

    // ---- layout ----
    readonly property int gutter: 56
    readonly property int radius: 4

    // ---- motion ----
    readonly property int quick: 180
    readonly property int pop: 350
    readonly property int slide: 400

    // ---- per-event presentation ----
    readonly property var eventLook: ({
        "EVT01": { art: "tt", accent: "#6B73E8", block: "#1E2257", edge: "#8B95FF", short: "TechTalk 2026",
                   blurb: "Four speakers, one stage — an afternoon on applied AI, systems and the projects students are building next." },
        "EVT02": { art: "hm", accent: "#E07AA8", block: "#3E1428", edge: "#E07AA8", short: "Hamlet",
                   blurb: "The Dramatics Society's modern staging of Shakespeare's tragedy." },
        "EVT03": { art: "rb", accent: "#3FD8C6", block: "#0B3A3E", edge: "#5FF0DC", short: "Robotics Expo",
                   blurb: "Twelve student teams, one arena. Live runs, judges' questions and the final podium." },
        "EVT04": { art: "qw", accent: "#F0A050", block: "#45260F", edge: "#F0A050", short: "Qawwali",
                   blurb: "An evening of qawwali in the open air — lanterns, harmonium and a full ensemble." },
        "EVT05": { art: "sp", accent: "#F5B544", block: "#3A2408", edge: "#F5B544", short: "Pitch Night",
                   blurb: "Eight founding teams, five minutes each, one panel. The audience votes for the final award." },
        "EVT06": { art: "jz", accent: "#F2D08A", block: "#0E3328", edge: "#F2D08A", short: "Winter Jazz",
                   blurb: "The university big band closes the term with standards and new student arrangements." }
    })

    readonly property var eventTitles: ({
        "EVT01": "University TechTalk 2026", "EVT02": "Hamlet, Reimagined", "EVT03": "Robotics Expo Finals",
        "EVT04": "Qawwali Under the Stars", "EVT05": "Startup Pitch Night", "EVT06": "Winter Jazz Ensemble"
    })

    // Bespoke artwork only for the sample events (ID *and* title must match), so a
    // new event that happens to get ID EVT01 never inherits the TechTalk poster.
    function hasArt(eventId, title) {
        return eventLook[eventId] !== undefined && (title === undefined || title === "" || eventTitles[eventId] === title)
    }

    // ---- generated artwork for every other event ----
    readonly property var palettes: [
        { top: "#2F3590", bottom: "#050507", accent: "#C9D2FF", block: "#1E2257" },
        { top: "#0B3F44", bottom: "#020909", accent: "#5FF0DC", block: "#0B3A3E" },
        { top: "#0A1033", bottom: "#D2722A", accent: "#FFD58A", block: "#45260F" },
        { top: "#3A2408", bottom: "#040302", accent: "#F5B544", block: "#3A2408" },
        { top: "#0E3328", bottom: "#020806", accent: "#F2D08A", block: "#0E3328" },
        { top: "#5A0B18", bottom: "#120305", accent: "#FFB4A8", block: "#4A0E18" },
        { top: "#3B1460", bottom: "#07030D", accent: "#D7A8FF", block: "#2E1050" },
        { top: "#0A2A5E", bottom: "#020611", accent: "#7FC8FF", block: "#0A244F" },
        { top: "#5E1240", bottom: "#0B0208", accent: "#FF9FCB", block: "#4A0F33" },
        { top: "#26330A", bottom: "#050702", accent: "#C8F03A", block: "#222E09" }
    ]
    function hash(s) {
        let h = 2166136261
        for (let i = 0; i < s.length; ++i) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0 }
        return h >>> 0
    }
    // Deterministic pseudo-random number in [0, 1) for (seed, i).
    function rand(seed, i) {
        const x = Math.sin((seed % 100000) * 12.9898 + i * 78.233) * 43758.5453
        return x - Math.floor(x)
    }
    function withAlpha(c, a) { const k = Qt.lighter(c, 1.0); return Qt.rgba(k.r, k.g, k.b, a) }
    function palette(title, category) { return palettes[hash((title || "") + "|" + (category || "")) % palettes.length] }

    // Picks a motif from words in the title first, then from the category.
    function artKind(title, category) {
        const t = (title || "").toLowerCase()
        const rules = [
            ["theatre", /drama|theatre|theater|\bplay\b|hamlet|shakespeare|comedy|improv|musical|stage show/],
            ["film", /film|movie|cinema|screening|documentary/],
            ["sport", /sport|cricket|football|futsal|match|tournament|marathon|\brace\b|athletic|basketball|badminton|hockey|olympiad/],
            ["festival", /festival|\bfest\b|\bfair\b|mela|carnival|food|gala|celebration|\beid\b|diwali|new year|party/],
            ["art", /\bart\b|\barts\b|exhibition|gallery|design|photograph|paint|sculpt/],
            ["music", /jazz|music|concert|qawwali|\bband\b|choir|orchestra|song|\bdj\b|recital|sitar|rock|gig|mushaira|karaoke/],
            ["tech", /robot|tech|hack|code|coding|\bai\b|data|cyber|software|engineer|expo|science|game|esports|drone/],
            ["talk", /talk|summit|pitch|lecture|conference|seminar|keynote|panel|workshop|debate|forum|symposium|startup|career|session/]
        ]
        for (const r of rules) if (r[1].test(t)) return r[0]
        const c = (category || "").toLowerCase()
        if (c === "talks") return "talk"
        if (c === "music") return "music"
        if (c === "tech") return "tech"
        if (c === "theatre") return "theatre"
        if (c === "sports") return "sport"
        if (c === "film") return "film"
        if (c === "festival") return "festival"
        if (c === "art") return "art"
        return "event"
    }

    function look(eventId, title, category) {
        if (hasArt(eventId, title)) return eventLook[eventId]
        const p = palette(title, category)
        return { art: "", accent: p.accent, block: p.block, edge: p.accent, short: title || "", blurb: "" }
    }
    function art(eventId) { return "qrc:/qt/qml/SeatCraft/assets/art/" + eventLook[eventId].art + ".svg" }
    function shortTitle(ev) { return hasArt(ev.id, ev.title) ? eventLook[ev.id].short : ev.title }
    function blurb(ev) { return hasArt(ev.id, ev.title) ? eventLook[ev.id].blurb : "" }
}
