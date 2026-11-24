import QtQuick

// Event key art. The six sample events use their hand-made SVG posters;
// every other event gets a generated poster based on its name and type.
Rectangle {
    id: root
    property string eventId
    property string title: ""        // optional; looked up from eventId when empty
    property string category: ""
    property bool showText: true

    readonly property var ev: title !== "" ? ({ title: title, category: category })
                                           : ((app.revision, app.event(eventId)) || ({}))
    readonly property bool bespoke: Theme.hasArt(eventId, ev.title)

    color: Theme.look(eventId, ev.title, ev.category).block
    clip: true

    Image {
        visible: root.bespoke
        anchors.fill: parent
        source: root.bespoke ? Theme.art(root.eventId) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.max(200, root.width * 2)
        smooth: true
        asynchronous: true
    }
    GeneratedArt {
        visible: !root.bespoke
        anchors.fill: parent
        title: root.ev.title || ""
        category: root.ev.category || ""
        showText: root.showText && root.width >= 90
    }
}
