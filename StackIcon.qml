import QtQuick
import QtQuick.Shapes
import qs.Commons

// The bar icon: three stacked layers, one per package source. Bottom is Arch
// (the base system), middle is Omarchy (built on it), top is AUR (extras).
//
// - The whole stack is solid when there are system updates, outlines otherwise.
// - While checking, the layers still being checked pulse in a wave from the
//   bottom up; a layer holds steady once its source has finished.
//
// Drawn on a 24×24 grid with 2-unit round strokes, like Material icons.
Item {
  id: icon

  property color color: "white"
  property bool filled: false
  property bool checking: false
  property bool archDone: false
  property bool aurDone: false
  readonly property bool solid: filled && !checking

  width: 24
  height: 24

  // Chevron layer centred at y = c: a line when hollow, a thin band when solid.
  function chevronLine(c) {
    return "M3.5," + (c - 4.25) + "L12," + c + "L20.5," + (c - 4.25)
  }
  function chevronBand(c) {
    var t = 0.7
    return "M3.5," + (c - 4.25 - t) + "L12," + (c - t) + "L20.5," + (c - 4.25 - t)
      + "L20.5," + (c - 4.25 + t) + "L12," + (c + t) + "L3.5," + (c - 4.25 + t) + "Z"
  }
  readonly property string diamond: "M12,2L20.5,6.25L12,10.5L3.5,6.25Z"

  // Fixed footprint, so the bar's optical centring doesn't shift as layers
  // change between outline and solid or fade while pulsing.
  Rectangle {
    x: 2.5
    y: 1
    width: 19
    height: 21.4
    color: "transparent"
  }

  component Layer: Item {
    id: layer
    property string outlinePath: ""
    property string solidPath: ""
    property bool pulsing: false
    property int delay: 0
    anchors.fill: parent

    SequentialAnimation on opacity {
      running: layer.pulsing && !Style.reduceMotion
      loops: Animation.Infinite
      onRunningChanged: if (!running) layer.opacity = 1
      PauseAnimation { duration: layer.delay }
      NumberAnimation { to: 0.3; duration: 300; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1; duration: 300; easing.type: Easing.InOutSine }
      PauseAnimation { duration: 400 - layer.delay }
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      opacity: icon.solid ? 0 : 1
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      ShapePath {
        strokeColor: icon.color
        strokeWidth: 2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: layer.outlinePath }
      }
    }
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      opacity: icon.solid ? 1 : 0
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      ShapePath {
        strokeColor: icon.color
        strokeWidth: 2
        fillColor: icon.color
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: layer.solidPath }
      }
    }
  }

  Layer {  // Arch
    outlinePath: icon.chevronLine(21)
    solidPath: icon.chevronBand(21)
    pulsing: icon.checking && !icon.archDone
    delay: 0
  }
  Layer {  // Omarchy
    outlinePath: icon.chevronLine(15.5)
    solidPath: icon.chevronBand(15.5)
    pulsing: icon.checking && !icon.archDone
    delay: 200
  }
  Layer {  // AUR
    outlinePath: icon.diamond
    solidPath: icon.diamond
    pulsing: icon.checking && !icon.aurDone
    delay: 400
  }
}
