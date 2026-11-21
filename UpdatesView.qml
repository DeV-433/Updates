import QtQuick
// Controls is imported before qs.Ui so Button keeps resolving to the Omarchy widget.
import QtQuick.Controls
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// The flyout's content. All state and actions live on `ctl` (Panel.qml), so
// this view can also be rendered on its own with mock data.
Column {
  id: view

  property var ctl: null
  property string filter: "all"

  readonly property color fg: ctl ? ctl.foreground : Commons.Color.foreground
  readonly property color muted: Commons.Color.muted
  readonly property color urgent: Commons.Color.urgent
  readonly property color warn: Commons.Color.warning
  readonly property int radius: Math.min(Style.cornerRadius, Style.space(8))
  readonly property int total: ctl ? ctl.total : 0
  readonly property bool partial: ctl ? (ctl.aurFailed || ctl.archFailed) : false

  // "idle" | "checking" | "error" | "clean" | "pending"
  readonly property string phase: !ctl ? "idle"
    : ctl.checking ? "checking"
    : ctl.errorMessage !== "" ? "error"
    : !ctl.checked ? "idle"
    : total === 0 ? "clean" : "pending"

  readonly property color phaseColor: phase === "pending" ? Commons.Color.accent
    : phase === "clean" ? (ctl ? ctl.paletteColor("green", Commons.Color.accent) : Commons.Color.accent)
    : phase === "error" ? urgent
    : phase === "checking" ? Commons.Color.accent
    : muted

  readonly property var shown: {
    if (!ctl) return []
    if (filter === "all") return ctl.updates
    var f = filter
    return ctl.updates.filter(function(u) { return u.source === f })
  }

  // Fall back to "all" when the chosen repo has nothing left in it.
  onTotalChanged: if (filter !== "all" && ctl && ctl.count(filter) === 0) filter = "all"

  width: parent ? parent.width : 0
  spacing: Style.space(12)

  // ── Header ────────────────────────────────────────────────────────────
  Item {
    width: parent.width
    height: Math.max(headerText.implicitHeight, refreshButton.implicitHeight)

    Column {
      id: headerText
      anchors.left: parent.left
      anchors.right: refreshButton.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        textFormat: Text.PlainText
        text: "SYSTEM UPDATES"
        color: view.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: Style.space(1.5)
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: view.ctl && view.ctl.checked && !view.ctl.checking ? view.ctl.agoText() : "Arch · Omarchy · AUR"
        color: view.fg
        opacity: 0.7
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    Button {
      id: refreshButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      bordered: true
      iconText: "󰑐"
      iconSpinning: view.ctl ? view.ctl.checking : false
      text: view.phase === "checking" ? "Checking" : "Check"
      enabled: view.phase !== "checking"
      onClicked: if (view.ctl) view.ctl.check()
    }
  }

  // ── Hero ──────────────────────────────────────────────────────────────
  // Pending: a big count beside a per-repo breakdown that doubles as the
  // list filter. Every other state: one glyph and two lines, no chrome.
  Item {
    id: hero
    width: parent.width
    height: view.phase === "pending" ? pendingHero.implicitHeight : statusHero.implicitHeight

    // Status line for idle / checking / clean / error.
    Row {
      id: statusHero
      visible: view.phase !== "pending"
      width: parent.width
      spacing: Style.space(12)

      Text {
        id: statusGlyph
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: view.phase === "clean" ? "󰗡"
          : view.phase === "error" ? "󰗖"
          : view.phase === "checking" ? "󰓦"
          : "󰏗"
        color: view.phaseColor
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        RotationAnimator on rotation {
          running: view.phase === "checking" && view.visible
          from: 0; to: 360
          duration: 1400
          loops: Animation.Infinite
          onRunningChanged: if (!running) statusGlyph.rotation = 0
        }
      }

      Column {
        width: parent.width - statusGlyph.width - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)
        Text {
          width: parent.width
          textFormat: Text.PlainText
          elide: Text.ElideRight
          text: view.phase === "clean" ? (view.partial ? "Nothing found" : "All caught up")
            : view.phase === "error" ? "Check failed"
            : view.phase === "checking" ? "Checking…"
            : "Not checked yet"
          color: view.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
        }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          text: view.phase === "clean" ? (view.partial ? "Some sources could not be checked" : "Your system is up to date")
            : view.phase === "error" ? (view.ctl ? view.ctl.errorMessage : "")
            : view.phase === "checking" ? "Syncing package databases"
            : "Press Check to look for updates"
          color: view.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }

    // Count + breakdown for pending updates.
    Item {
      id: pendingHero
      visible: view.phase === "pending"
      width: parent.width
      implicitHeight: Math.max(countBlock.implicitHeight, legend.implicitHeight)

      Column {
        id: countBlock
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
          textFormat: Text.PlainText
          text: Commons.I18n.formatNumber(view.total)
          color: view.fg
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.displayLarge * 1.6)
          font.bold: true
          lineHeight: 0.9
        }
        Text {
          textFormat: Text.PlainText
          text: view.total === 1 ? "UPDATE PENDING" : "UPDATES PENDING"
          color: view.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: Style.space(1.5)
        }
      }

      // Per-repo breakdown; click a row to filter the list, again to clear.
      Column {
        id: legend
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(150)
        spacing: Style.space(2)

        Repeater {
          model: ["omarchy", "arch", "aur"]

          Rectangle {
            id: legendRow
            required property string modelData
            readonly property int n: view.ctl ? view.ctl.count(modelData) : 0
            readonly property color tint: view.ctl ? view.ctl.repoColor(modelData) : view.fg
            readonly property bool selected: view.filter === modelData
            readonly property bool dimmed: view.filter !== "all" && !selected
            width: legend.width
            height: Style.space(22)
            radius: view.radius
            color: selected ? Util.alpha(tint, 0.14) : legendMouse.containsMouse && n > 0 ? Util.alpha(tint, 0.07) : "transparent"
            opacity: n === 0 ? 0.35 : dimmed ? 0.45 : 1
            Behavior on color { ColorAnimation { duration: Style.duration(120) } }
            Behavior on opacity { NumberAnimation { duration: Style.duration(150) } }

            Rectangle {
              id: dot
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(7)
              height: width
              radius: width / 2
              color: legendRow.tint
            }
            Text {
              anchors.left: dot.right
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: view.ctl ? view.ctl.sourceLabel(legendRow.modelData) : ""
              color: view.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: legendRow.selected
            }
            Text {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: Commons.I18n.formatNumber(legendRow.n)
              color: legendRow.tint
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            MouseArea {
              id: legendMouse
              anchors.fill: parent
              enabled: legendRow.n > 0
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: view.filter = legendRow.selected ? "all" : legendRow.modelData
            }
          }
        }
      }
    }
  }

  // Indeterminate progress while checking; the repo split otherwise.
  Item {
    width: parent.width
    height: Style.space(3)
    visible: view.phase === "checking" || view.phase === "pending"
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: Util.alpha(view.fg, 0.08)
    }

    Rectangle {
      id: sweep
      visible: view.phase === "checking"
      width: parent.width * 0.3
      height: parent.height
      radius: height / 2
      color: Commons.Color.accent
      NumberAnimation on x {
        running: sweep.visible && view.visible
        from: -sweep.width
        to: sweep.parent.width
        duration: 1100
        loops: Animation.Infinite
      }
    }

    Row {
      visible: view.phase === "pending"
      anchors.fill: parent
      spacing: Style.space(2)
      Repeater {
        model: ["omarchy", "arch", "aur"]
        Rectangle {
          required property string modelData
          readonly property int n: view.ctl ? view.ctl.count(modelData) : 0
          visible: n > 0
          height: parent.height
          width: view.total > 0 ? Math.max(Style.space(4), (parent.width - Style.space(4)) * n / view.total) : 0
          radius: height / 2
          color: view.ctl ? view.ctl.repoColor(modelData) : view.fg
          opacity: view.filter === "all" || view.filter === modelData ? 1 : 0.3
          Behavior on width { NumberAnimation { duration: Style.duration(240); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
          Behavior on opacity { NumberAnimation { duration: Style.duration(150) } }
        }
      }
    }
  }

  // Reboot notice
  Row {
    visible: view.phase === "pending" && view.ctl && view.ctl.rebootNeeded
    spacing: Style.space(6)
    Text {
      textFormat: Text.PlainText
      text: "󰜉"
      color: view.warn
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Text {
      textFormat: Text.PlainText
      text: "Includes core packages · reboot afterwards"
      color: view.warn
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  // ── Warnings ──────────────────────────────────────────────────────────
  Rectangle {
    width: parent.width
    visible: view.ctl && view.ctl.checked && view.partial && view.phase !== "checking"
    height: warnRow.implicitHeight + Style.space(14)
    radius: view.radius
    color: Util.alpha(view.urgent, 0.1)
    border.width: 1
    border.color: Util.alpha(view.urgent, 0.35)

    Row {
      id: warnRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)
      Text {
        textFormat: Text.PlainText
        text: "󰀪"
        color: view.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Text {
        width: parent.width - Style.space(24)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: !view.ctl ? ""
          : view.ctl.aurFailed && view.ctl.archFailed ? "Arch and AUR checks failed"
          : view.ctl.aurFailed ? "AUR check failed · AUR updates are not shown"
          : "Arch check failed · Arch and Omarchy updates are not shown"
        color: view.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ── Package list ──────────────────────────────────────────────────────
  Rectangle {
    width: parent.width
    visible: view.phase === "pending"
    height: list.height + Style.space(8)
    radius: view.radius
    color: Util.alpha(view.fg, 0.03)
    border.width: 1
    border.color: Util.alpha(view.fg, 0.08)

    ListView {
      id: list
      x: Style.space(4)
      y: Style.space(4)
      width: parent.width - Style.space(8)
      height: Math.min(contentHeight, Style.space(264))
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      model: view.shown
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      delegate: Rectangle {
        id: rowItem
        required property var modelData
        required property int index
        readonly property color tint: view.ctl ? view.ctl.repoColor(modelData.source) : view.fg
        readonly property bool core: view.ctl ? view.ctl.isCorePackage(modelData.name) : false
        // Split the new version at the first character that differs from the old one.
        readonly property int splitAt: {
          var a = String(modelData.from), b = String(modelData.to), i = 0
          while (i < a.length && i < b.length && a[i] === b[i]) i++
          // Back up to the start of the changed segment so "1.2.10" vs "1.2.9" highlights "10".
          while (i > 0 && /[0-9A-Za-z]/.test(b[i - 1])) i--
          return i
        }

        width: ListView.view.width
        height: Style.space(30)
        radius: view.radius
        color: rowMouse.containsMouse ? Util.alpha(tint, 0.1)
          : index % 2 === 1 ? Util.alpha(view.fg, 0.025) : "transparent"

        MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true }

        Rectangle {
          id: strip
          anchors.left: parent.left
          anchors.leftMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(3)
          height: Style.space(14)
          radius: width / 2
          color: rowItem.tint
        }

        Text {
          id: nameText
          anchors.left: strip.right
          anchors.leftMargin: Style.space(10)
          anchors.right: coreMark.visible ? coreMark.left : versions.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          elide: Text.ElideRight
          text: rowItem.modelData.name
          color: view.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          id: coreMark
          visible: rowItem.core
          anchors.right: versions.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "󰜉"
          color: view.warn
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Row {
          id: versions
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(5)

          Text {
            width: Math.min(implicitWidth, Style.space(80))
            elide: Text.ElideLeft
            textFormat: Text.PlainText
            text: rowItem.modelData.from
            color: view.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            textFormat: Text.PlainText
            text: "󰁔"
            color: Util.alpha(rowItem.tint, 0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          Row {
            Text {
              textFormat: Text.PlainText
              text: String(rowItem.modelData.to).slice(0, rowItem.splitAt)
              color: Util.alpha(view.fg, 0.75)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Text {
              width: Math.min(implicitWidth, Style.space(80))
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: String(rowItem.modelData.to).slice(rowItem.splitAt)
              color: rowItem.tint
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }
      }
    }
  }

  // ── Footer ────────────────────────────────────────────────────────────
  Button {
    width: parent.width
    visible: view.phase === "pending"
    bordered: true
    selected: true
    iconText: "󰇚"
    text: view.total === 1 ? "Install 1 update" : "Install " + Commons.I18n.formatNumber(view.total) + " updates"
    onClicked: if (view.ctl) view.ctl.runUpdate()
  }
}
