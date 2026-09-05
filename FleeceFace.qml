import QtQuick

// The interim sheepish robot. Three overlapping fleece lobes behind a robot
// head with the two-bar eyes from Terminal Delight's wall art, coloured by
// tier — and only by tier, because the fleece is the squint-from-across-the-
// room signal:
//
//   good      → white   (working, healthy idle)
//   attention → grey    (done-and-unseen, a question waiting, unknown)
//   error     → black   (broken)
//
// These are literal, not themed: the doctrine is the colour. The outline
// tracks the bar's foreground so the shape survives any Omarchy scheme.
//
// This whole file is a placeholder photograph. The canonical sheep-robot is
// being authored in agent-playhouse (web/art/robot.svg) and arrives here
// through the publish pipeline; when it lands, this component becomes an
// Image and the vectors below are deleted.
Item {
  id: face

  // "good" | "attention" | "error"
  property string tier: "good"
  property color outline: "#808080"

  readonly property color fleeceColor:
    tier === "error" ? "#141414"
    : tier === "attention" ? "#5f5f5a"
    : "#eceae3"
  // Eyes must read against the fleece, so they flip with it.
  readonly property color eyeColor:
    tier === "good" ? "#2a2a28" : "#eceae3"

  implicitWidth: 96
  implicitHeight: 72

  // Fleece: three lobes, one body. A cloud with opinions.
  Rectangle {
    x: parent.width * 0.06
    y: parent.height * 0.28
    width: parent.width * 0.42
    height: width
    radius: width / 2
    color: face.fleeceColor
    border.color: face.outline
    border.width: 1
  }
  Rectangle {
    x: parent.width * 0.52
    y: parent.height * 0.28
    width: parent.width * 0.42
    height: width
    radius: width / 2
    color: face.fleeceColor
    border.color: face.outline
    border.width: 1
  }
  Rectangle {
    x: parent.width * 0.24
    y: parent.height * 0.10
    width: parent.width * 0.52
    height: width
    radius: width / 2
    color: face.fleeceColor
    border.color: face.outline
    border.width: 1
  }
  // Body fill to swallow the inner borders where the lobes overlap.
  Rectangle {
    x: parent.width * 0.14
    y: parent.height * 0.34
    width: parent.width * 0.72
    height: parent.height * 0.42
    radius: height * 0.4
    color: face.fleeceColor
  }

  // Ears, slightly drooped. The sheepish part.
  Rectangle {
    x: parent.width * 0.02
    y: parent.height * 0.40
    width: parent.width * 0.16
    height: parent.height * 0.13
    radius: height / 2
    rotation: -18
    color: face.fleeceColor
    border.color: face.outline
    border.width: 1
  }
  Rectangle {
    x: parent.width * 0.82
    y: parent.height * 0.40
    width: parent.width * 0.16
    height: parent.height * 0.13
    radius: height / 2
    rotation: 18
    color: face.fleeceColor
    border.color: face.outline
    border.width: 1
  }

  // The robot face plate, and the two-bar eyes the TD wall wears.
  Rectangle {
    id: plate
    x: parent.width * 0.30
    y: parent.height * 0.34
    width: parent.width * 0.40
    height: parent.height * 0.40
    radius: height * 0.22
    color: face.tier === "good" ? "#f7f6f1" : Qt.darker(face.fleeceColor, 1.15)
    border.color: face.outline
    border.width: 1

    Rectangle {
      x: parent.width * 0.24
      y: parent.height * 0.22
      width: parent.width * 0.14
      height: parent.height * 0.56
      radius: width * 0.3
      color: face.eyeColor
    }
    Rectangle {
      x: parent.width * 0.62
      y: parent.height * 0.22
      width: parent.width * 0.14
      height: parent.height * 0.56
      radius: width * 0.3
      color: face.eyeColor
    }
  }

  // Antenna. Still a robot under all that wool.
  Rectangle {
    x: parent.width * 0.49
    y: parent.height * 0.02
    width: Math.max(2, parent.width * 0.02)
    height: parent.height * 0.10
    color: face.outline
  }
  Rectangle {
    x: parent.width * 0.47
    y: 0
    width: parent.width * 0.06
    height: width
    radius: width / 2
    color: face.tier === "error" ? "#c04040" : face.outline
  }
}
