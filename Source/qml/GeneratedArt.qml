import QtQuick
import QtQuick.Shapes

// Procedural poster for events without bespoke artwork. The motif follows the
// event's name/type (talk, music, tech, theatre, sport, film, festival, art) and
// the colours and composition come from a hash of the title, so every new
// event gets its own artwork. Drawn in a 200 x 300 space and cropped to fit.
Item {
    id: root
    property string title: ""
    property string category: ""
    property bool showText: true
    clip: true

    readonly property int seed: Theme.hash(title + "|" + category)
    readonly property string kind: Theme.artKind(title, category)
    readonly property var pal: Theme.palette(title, category)
    function r(i) { return Theme.rand(root.seed, i) }

    Item {
        id: canvas
        width: 200; height: 300
        readonly property real k: Math.max(root.width / 200, root.height / 300)
        scale: k
        transformOrigin: Item.TopLeft
        x: (root.width - 200 * k) / 2
        y: (root.height - 300 * k) / 2

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: root.pal.top }
                GradientStop { position: 1; color: root.pal.bottom }
            }
        }
        Shape {      // soft glow
            anchors.fill: parent
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: 60 + root.r(1) * 80; centerY: 90 + root.r(2) * 80; centerRadius: 120
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: Theme.withAlpha(root.pal.accent, 0.35) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathSvg { path: "M0 0 L200 0 L200 300 L0 300 Z" }
            }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: ({ talk: talk, music: music, tech: tech, theatre: theatre, sport: sport,
                                film: film, festival: festival, art: art })[root.kind] || generic
        }

        Column {
            visible: root.showText
            x: 14; y: 16; width: 172
            spacing: 4
            Text {
                width: parent.width; height: 54
                text: root.title.toUpperCase()
                wrapMode: Text.WordWrap; maximumLineCount: 2
                fontSizeMode: Text.Fit; minimumPixelSize: 12
                font.family: Theme.display; font.variableAxes: Theme.displayAxes; font.weight: Font.Black; font.pixelSize: 26
                lineHeight: 0.9
                color: Qt.lighter(root.pal.accent, 1.25)
            }
            Text {
                text: (root.category || "Event").toUpperCase() + " · SEATCRAFT"
                font.family: Theme.mono; font.pixelSize: 9
                color: Theme.withAlpha(root.pal.accent, 0.7)
            }
        }
    }

    // ---------------------------------------------------------------- motifs
    Component {
        id: talk
        Item {
            readonly property real dx: (root.r(3) - 0.5) * 50
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: 240
                        GradientStop { position: 0; color: Theme.withAlpha(root.pal.accent, 0.55) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    PathSvg { path: "M" + (90 + dx) + " 0 L" + (110 + dx) + " 0 L" + (152 + dx) + " 236 L" + (48 + dx) + " 236 Z" }
                }
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.35); strokeWidth: 1; fillColor: "transparent"
                    PathAngleArc { centerX: 100 + dx; centerY: 110; radiusX: 46 + root.r(4) * 20; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeWidth: -1; fillColor: Theme.withAlpha(root.pal.accent, 0.22)
                    PathAngleArc { centerX: 100 + dx; centerY: 238; radiusX: 70; radiusY: 10; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeWidth: -1; fillColor: "#050507"
                    PathSvg { path: "M0 274 q14-14 28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 t28 0 L200 300 L0 300 Z" }
                }
            }
            Rectangle { x: 93 + dx; y: 196; width: 14; height: 42; radius: 7; color: "#050507" }
            Rectangle { x: 92.5 + dx; y: 172; width: 15; height: 15; radius: 7.5; color: "#050507" }
            Rectangle { x: 118 + dx; y: 210; width: 26; height: 28; color: Qt.darker(root.pal.top, 1.6); border.color: Theme.withAlpha(root.pal.accent, 0.4) }
        }
    }

    Component {
        id: music
        Item {
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.9); strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathSvg { path: "M0 " + (150 + root.r(5) * 30) + " Q 25 " + (110 + root.r(6) * 30) + " 50 " + (150 + root.r(5) * 30) + " T 100 " + (150 + root.r(5) * 30) + " T 150 " + (150 + root.r(5) * 30) + " T 200 " + (150 + root.r(5) * 30) }
                }
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.5); strokeWidth: 2; fillColor: "transparent"
                    PathSvg { path: "M0 " + (185 + root.r(7) * 20) + " Q 33 " + (150 + root.r(8) * 20) + " 66 " + (185 + root.r(7) * 20) + " T 133 " + (185 + root.r(7) * 20) + " T 200 " + (185 + root.r(7) * 20) }
                }
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.3); strokeWidth: 1.5; fillColor: "transparent"
                    PathSvg { path: "M0 " + (120 + root.r(9) * 20) + " Q 20 " + (100 + root.r(10) * 20) + " 40 " + (120 + root.r(9) * 20) + " T 80 " + (120 + root.r(9) * 20) + " T 120 " + (120 + root.r(9) * 20) + " T 160 " + (120 + root.r(9) * 20) + " T 200 " + (120 + root.r(9) * 20) }
                }
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.35); strokeWidth: 1; fillColor: "transparent"
                    PathAngleArc { centerX: 100; centerY: 250; radiusX: 34; radiusY: 34; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.2); strokeWidth: 1; fillColor: "transparent"
                    PathAngleArc { centerX: 100; centerY: 250; radiusX: 58; radiusY: 58; startAngle: 0; sweepAngle: 360 }
                }
            }
            Text { x: 30 + root.r(11) * 40; y: 70 + root.r(12) * 30; text: "♪"; font.family: "Segoe UI Symbol"; font.pixelSize: 34; color: root.pal.accent }
            Text { x: 120 + root.r(13) * 40; y: 200 + root.r(14) * 30; text: "♫"; font.family: "Segoe UI Symbol"; font.pixelSize: 30; color: Theme.withAlpha(root.pal.accent, 0.8) }
            Rectangle { x: 92; y: 242; width: 16; height: 16; radius: 8; color: root.pal.accent }
        }
    }

    Component {
        id: tech
        Item {
            id: techRoot
            readonly property var nodes: [0, 1, 2, 3, 4, 5].map((i) => ({ x: 20 + root.r(20 + i) * 160, y: 112 + root.r(30 + i) * 110 }))
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.22); strokeWidth: 1; fillColor: "transparent"
                    PathSvg { path: "M0 230 L200 230 M0 250 L200 250 M0 274 L200 274 M100 230 L100 300 M100 230 L20 300 M100 230 L180 300 M100 230 L-60 300 M100 230 L260 300" }
                }
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.8); strokeWidth: 2.5; fillColor: "transparent"; joinStyle: ShapePath.MiterJoin
                    PathSvg {
                        path: {
                            const n = techRoot.nodes
                            let d = "M" + n[0].x + " " + n[0].y
                            for (let i = 1; i < n.length; ++i) d += " H" + n[i].x + " V" + n[i].y
                            return d
                        }
                    }
                }
            }
            Repeater {
                model: techRoot.nodes
                Rectangle { x: modelData.x - 6; y: modelData.y - 6; width: 12; height: 12; radius: index % 2 ? 6 : 2
                            color: index % 2 ? root.pal.accent : Qt.darker(root.pal.top, 2); border.color: root.pal.accent; border.width: 2 }
            }
        }
    }

    Component {
        id: theatre
        Item {
            Repeater {
                model: 8
                Rectangle { x: index < 4 ? index * 11 : 200 - (index - 3) * 11; y: 0; width: 11; height: 300 - (index % 4) * 18
                            gradient: Gradient { orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.darker(root.pal.top, 1.1) }
                                GradientStop { position: 0.5; color: Qt.lighter(root.pal.top, 1.5) }
                                GradientStop { position: 1; color: Qt.darker(root.pal.top, 1.4) } } }
            }
            Rectangle { x: 0; y: 0; width: 200; height: 26; color: Qt.darker(root.pal.top, 1.3) }
            Repeater { model: 9; Rectangle { x: index * 24 - 4; y: 18; width: 24; height: 16; radius: 8; color: Qt.darker(root.pal.top, 1.3) } }
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: 100; centerY: 170; centerRadius: 80; focalX: 100; focalY: 170
                        GradientStop { position: 0; color: Theme.withAlpha(root.pal.accent, 0.5) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    PathSvg { path: "M0 0 L200 0 L200 300 L0 300 Z" }
                }
                ShapePath {    // drama mask
                    strokeColor: root.pal.accent; strokeWidth: 2; fillColor: Theme.withAlpha(root.pal.accent, 0.15)
                    PathSvg { path: "M74 140 Q100 128 126 140 Q128 180 100 196 Q72 180 74 140 Z" }
                }
                ShapePath {
                    strokeWidth: -1; fillColor: Qt.darker(root.pal.top, 2.5)
                    PathSvg { path: "M84 154 Q90 150 96 156 Q90 160 84 154 Z M104 156 Q110 150 116 154 Q110 160 104 156 Z" }
                }
                ShapePath {
                    strokeColor: root.pal.accent; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathSvg { path: root.r(40) > 0.5 ? "M88 176 Q100 186 112 176" : "M88 182 Q100 172 112 182" }
                }
            }
            Rectangle { x: 0; y: 250; width: 200; height: 50; color: Qt.darker(root.pal.bottom, 1.2) }
        }
    }

    Component {
        id: sport
        Item {
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.5); strokeWidth: 2; fillColor: "transparent"
                    PathSvg { path: "M30 160 A70 40 0 1 0 170 160 A70 40 0 1 0 30 160 Z" }
                }
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.25); strokeWidth: 1.5; fillColor: "transparent"
                    PathSvg { path: "M10 160 A90 58 0 1 0 190 160 A90 58 0 1 0 10 160 Z" }
                }
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: 200
                        GradientStop { position: 0; color: Theme.withAlpha(root.pal.accent, 0.35) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    PathSvg { path: "M0 0 L24 0 L110 200 L80 200 Z M200 0 L176 0 L90 200 L120 200 Z" }
                }
            }
            Rectangle {
                x: 70 + root.r(41) * 30; y: 190 + root.r(42) * 30; width: 44; height: 44; radius: 22
                color: root.pal.accent
                Rectangle { anchors.centerIn: parent; width: 2; height: 44; color: Qt.darker(root.pal.top, 2); rotation: 30 }
                Rectangle { anchors.centerIn: parent; width: 44; height: 2; color: Qt.darker(root.pal.top, 2); rotation: 30 }
            }
        }
    }

    Component {
        id: film
        Item {
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 200; y1: 40; x2: 0; y2: 260
                        GradientStop { position: 0; color: Theme.withAlpha(root.pal.accent, 0.5) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    PathSvg { path: "M190 40 L200 30 L200 60 L0 300 L0 200 Z" }
                }
            }
            Item {
                x: -20; y: 150 + root.r(43) * 30; width: 260; height: 64
                rotation: -14 - root.r(44) * 8
                Rectangle { anchors.fill: parent; color: "#0A0908" }
                Repeater { model: 13; Rectangle { x: 6 + index * 20; y: 5; width: 10; height: 7; radius: 2; color: Theme.withAlpha(root.pal.accent, 0.6) } }
                Repeater { model: 13; Rectangle { x: 6 + index * 20; y: 52; width: 10; height: 7; radius: 2; color: Theme.withAlpha(root.pal.accent, 0.6) } }
                Repeater { model: 5; Rectangle { x: 10 + index * 50; y: 16; width: 42; height: 32; color: Theme.withAlpha(root.pal.accent, 0.12 + index * 0.06); border.color: Theme.withAlpha(root.pal.accent, 0.5) } }
            }
            Rectangle { x: 150; y: 96; width: 40; height: 26; radius: 4; color: Qt.darker(root.pal.top, 2); border.color: root.pal.accent }
        }
    }

    Component {
        id: festival
        Item {
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.6); strokeWidth: 1; fillColor: "transparent"
                    PathSvg { path: "M0 100 Q100 160 200 100 M0 140 Q100 190 200 130" }
                }
                ShapePath {
                    strokeColor: Theme.withAlpha(root.pal.accent, 0.8); strokeWidth: 1.5; fillColor: "transparent"
                    PathSvg {
                        path: {
                            const cx = 60 + root.r(50) * 80, cy = 200 + root.r(51) * 30
                            let d = ""
                            for (let i = 0; i < 14; ++i) {
                                const a = i / 14 * Math.PI * 2, r1 = 8, r2 = 30 + root.r(60 + i) * 18
                                d += "M" + (cx + Math.cos(a) * r1) + " " + (cy + Math.sin(a) * r1) + " L" + (cx + Math.cos(a) * r2) + " " + (cy + Math.sin(a) * r2) + " "
                            }
                            return d
                        }
                    }
                }
            }
            Repeater {
                model: 9
                Rectangle {
                    readonly property real t: (index + 0.5) / 9
                    x: t * 200 - 4; y: 100 + 4 * t * (1 - t) * 30 - 4
                    width: 8; height: 8; radius: 4
                    color: index % 3 === 0 ? "#FFF1D6" : root.pal.accent
                }
            }
            Repeater {
                model: 8
                Shape {
                    readonly property real t: (index + 0.5) / 8
                    x: t * 200 - 8; y: 140 + 4 * t * (1 - t) * 25 - 2
                    width: 16; height: 18
                    ShapePath { strokeWidth: -1; fillColor: index % 2 ? root.pal.accent : Qt.lighter(root.pal.top, 2)
                                PathSvg { path: "M0 0 L16 0 L8 16 Z" } }
                }
            }
        }
    }

    Component {
        id: art
        Item {
            Rectangle { x: 20 + root.r(70) * 60; y: 90 + root.r(71) * 40; width: 90; height: 90; radius: 45; color: root.pal.accent; opacity: 0.85 }
            Rectangle { x: 90 + root.r(72) * 40; y: 150 + root.r(73) * 40; width: 70; height: 70; color: Qt.lighter(root.pal.top, 1.9); rotation: root.r(74) * 30 }
            Shape {
                anchors.fill: parent
                ShapePath { strokeWidth: -1; fillColor: Qt.darker(root.pal.bottom, 1.4)
                            PathSvg { path: "M20 270 L" + (70 + root.r(75) * 40) + " " + (190 + root.r(76) * 30) + " L130 270 Z" } }
                ShapePath { strokeColor: root.pal.accent; strokeWidth: 3; fillColor: "transparent"
                            PathSvg { path: "M10 " + (230 + root.r(77) * 20) + " L190 " + (200 + root.r(78) * 30) } }
            }
        }
    }

    Component {
        id: generic
        Item {
            Shape {
                anchors.fill: parent
                ShapePath { strokeColor: Theme.withAlpha(root.pal.accent, 0.5); strokeWidth: 1.5; fillColor: "transparent"
                            PathAngleArc { centerX: 100; centerY: 170; radiusX: 30; radiusY: 30; startAngle: 0; sweepAngle: 360 } }
                ShapePath { strokeColor: Theme.withAlpha(root.pal.accent, 0.3); strokeWidth: 1.5; fillColor: "transparent"
                            PathAngleArc { centerX: 100; centerY: 170; radiusX: 55; radiusY: 55; startAngle: 0; sweepAngle: 360 } }
                ShapePath { strokeColor: Theme.withAlpha(root.pal.accent, 0.15); strokeWidth: 1.5; fillColor: "transparent"
                            PathAngleArc { centerX: 100; centerY: 170; radiusX: 82; radiusY: 82; startAngle: 0; sweepAngle: 360 } }
                ShapePath { strokeWidth: -1; fillColor: "#050505"; PathSvg { path: "M0 262 Q100 222 200 262 L200 300 L0 300 Z" } }
            }
            Rectangle { x: 88; y: 158; width: 24; height: 24; radius: 12; color: root.pal.accent }
        }
    }
}
