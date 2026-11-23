import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// The flyout's content. All state and actions live on `ctl` (Panel.qml), so
// this view can also be rendered on its own with mock data.
Column {
  id: view

  property var ctl: null
  property string filter: "all"
  property bool showLocal: false
  // Plugins with local changes are hidden unless asked for.
  readonly property var shownPlugins: !ctl ? []
    : showLocal ? ctl.pluginUpdates
    : ctl.pluginUpdates.filter(function(p) { return !ctl.isLocal(p) })

  readonly property color fg: ctl ? ctl.foreground : Commons.Color.foreground
  readonly property color muted: Commons.Color.muted
  readonly property color urgent: Commons.Color.urgent
  readonly property color warn: Commons.Color.warning
  // Failures read as red, distinct from the yellow AUR/warning tones.
  readonly property color danger: ctl ? ctl.paletteColor("red", urgent) : urgent
  readonly property color pluginTint: ctl ? ctl.paletteColor("cyan", Commons.Color.accent) : Commons.Color.accent

  // Index in `to` where it starts to differ from `from`, backed up to the
  // start of that segment so "1.2.10" vs "1.2.9" highlights "10".
  function splitAt(from, to) {
    var a = String(from), b = String(to), i = 0
    while (i < a.length && i < b.length && a[i] === b[i]) i++
    while (i > 0 && /[0-9A-Za-z]/.test(b[i - 1])) i--
    return i
  }

  // `old → new`, with the changed part of `new` in the row's tint. Shared by
  // the package and plugin lists so both read the same.
  component VersionPair: Row {
    id: pair
    property string from: ""
    property string to: ""
    property color tint: view.fg
    readonly property int split: view.splitAt(from, to)
    spacing: Style.space(5)
    Text {
      width: Math.min(implicitWidth, Style.space(140))
      elide: Text.ElideLeft
      textFormat: Text.PlainText
      text: pair.from
      color: view.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Text {
      textFormat: Text.PlainText
      text: "󰁔"
      color: Util.alpha(pair.tint, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Row {
      Text {
        textFormat: Text.PlainText
        text: pair.to.slice(0, pair.split)
        color: Util.alpha(view.fg, 0.75)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Text {
        width: Math.min(implicitWidth, Style.space(140))
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: pair.to.slice(pair.split)
        color: pair.tint
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  // Placeholder rows with a light sweeping across, shown while results load.
  component Skeleton: Rectangle {
    id: skel
    property int rows: 3
    width: parent ? parent.width : 0
    height: rows * Style.space(30) + Style.space(8)
    radius: view.radius
    color: Util.alpha(view.fg, 0.03)
    border.width: 1
    border.color: Util.alpha(view.fg, 0.08)
    clip: true

    Column {
      x: Style.space(4)
      y: Style.space(4)
      width: parent.width - Style.space(8)
      Repeater {
        model: skel.rows
        Item {
          required property int index
          width: parent.width
          height: Style.space(30)
          Rectangle {
            id: skelStrip
            x: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(3)
            height: Style.space(14)
            radius: width / 2
            color: Util.alpha(view.fg, 0.1)
          }
          Rectangle {
            anchors.left: skelStrip.right
            anchors.leftMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * [0.32, 0.22, 0.4, 0.27, 0.35][index % 5]
            height: Style.space(8)
            radius: height / 2
            color: Util.alpha(view.fg, 0.08)
          }
          Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * [0.24, 0.3, 0.2, 0.28, 0.22][index % 5]
            height: Style.space(6)
            radius: height / 2
            color: Util.alpha(view.fg, 0.06)
          }
        }
      }
    }

    Rectangle {
      id: shimmer
      width: parent.width * 0.4
      height: parent.height
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Util.alpha(view.fg, 0.06) }
        GradientStop { position: 1.0; color: "transparent" }
      }
      NumberAnimation on x {
        running: skel.visible && view.visible && !Style.reduceMotion
        from: -shimmer.width
        to: skel.width
        duration: 1300
        loops: Animation.Infinite
      }
    }
  }

  // A source in the checking hero: a pulsing dot until it finishes, then a tick.
  component SourceChip: Row {
    id: chip
    property string label: ""
    property bool done: false
    property color tint: view.fg
    spacing: Style.space(5)
    Item {
      anchors.verticalCenter: parent.verticalCenter
      width: tick.implicitWidth
      height: tick.implicitHeight
      Rectangle {
        id: pulseDot
        anchors.centerIn: parent
        visible: !chip.done
        width: Style.space(6)
        height: width
        radius: width / 2
        color: chip.tint
        SequentialAnimation on opacity {
          running: pulseDot.visible && view.visible && !Style.reduceMotion
          loops: Animation.Infinite
          onRunningChanged: if (!running) pulseDot.opacity = 1
          NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        }
      }
      Text {
        id: tick
        anchors.centerIn: parent
        opacity: chip.done ? 1 : 0
        scale: chip.done ? 1 : 0.95
        Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
        textFormat: Text.PlainText
        text: "󰄬"
        color: chip.tint
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: chip.label
      color: chip.done ? view.fg : view.muted
      Behavior on color { ColorAnimation { duration: Style.duration(180) } }
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  // One-line notice: glyph and caption, no box.
  component NoticeLine: Row {
    id: line
    property string glyph: "󰀪"
    property string message: ""
    property color tone: view.warn
    width: parent ? parent.width : 0
    spacing: Style.space(6)
    Text {
      id: lineGlyph
      textFormat: Text.PlainText
      text: line.glyph
      color: line.tone
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Text {
      width: parent.width - lineGlyph.width - parent.spacing
      textFormat: Text.PlainText
      elide: Text.ElideRight
      text: line.message
      color: line.tone
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  // Tinted notice box, for the system check failing outright.
  component Notice: Rectangle {
    id: notice
    property string message: ""
    property color tone: view.danger
    width: parent ? parent.width : 0
    height: noticeRow.implicitHeight + Style.space(12)
    radius: view.radius
    color: Util.alpha(tone, 0.1)
    border.width: 1
    border.color: Util.alpha(tone, 0.35)
    Row {
      id: noticeRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)
      Text {
        id: noticeGlyph
        textFormat: Text.PlainText
        text: "󰀪"
        color: notice.tone
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Text {
        width: parent.width - noticeGlyph.width - parent.spacing
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: notice.message
        color: notice.tone
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
  readonly property int radius: Math.min(Style.cornerRadius, Style.space(8))
  readonly property int total: ctl ? ctl.systemTotal : 0
  readonly property bool partial: ctl ? (ctl.aurFailed || ctl.archFailed) : false

  // "idle" | "checking" | "error" | "clean" | "pending"
  readonly property string phase: !ctl ? "idle"
    : ctl.checking ? "checking"
    : ctl.errorMessage !== "" ? "error"
    : !ctl.checked ? "idle"
    : total === 0 ? "clean" : "pending"

  readonly property color phaseColor: phase === "pending" ? Commons.Color.accent
    : phase === "clean" ? (ctl ? ctl.paletteColor("green", Commons.Color.accent) : Commons.Color.accent)
    : phase === "error" ? danger
    : phase === "checking" ? Commons.Color.accent
    : muted

  readonly property var shown: {
    if (!ctl) return []
    if (filter === "all") return ctl.updates
    var f = filter
    return ctl.updates.filter(function(u) { return u.source === f })
  }

  // The lists use keyed ListModels rather than the arrays themselves, so a
  // re-check or filter change only adds/removes the rows that changed and
  // those rows can animate. Rows look their data up by key; the maps keep
  // entries of removed rows so they still render while fading out.
  property var pkgMap: ({})
  property var pluginMap: ({})
  ListModel { id: pkgModel }
  ListModel { id: pluginModel }

  function pkgKey(u) { return u.source + "/" + u.name }
  function modelKeys(model) {
    var keys = []
    for (var i = 0; i < model.count; i++) keys.push(model.get(i).key)
    return keys
  }
  // Reorders `model` to `keys` with the fewest removes/inserts/moves.
  function syncModel(model, keys) {
    var want = {}
    for (var w = 0; w < keys.length; w++) want[keys[w]] = true
    var cur = modelKeys(model)
    for (var i = cur.length - 1; i >= 0; i--)
      if (!want[cur[i]]) { model.remove(i); cur.splice(i, 1) }
    for (var j = 0; j < keys.length; j++) {
      if (cur[j] === keys[j]) continue
      var at = cur.indexOf(keys[j], j)
      if (at < 0) { model.insert(j, { key: keys[j] }); cur.splice(j, 0, keys[j]) }
      else { model.move(at, j, 1); cur.splice(at, 1); cur.splice(j, 0, keys[j]) }
    }
  }
  // Lookup for the rows: the new items, plus old entries for rows that are
  // about to be removed so they still render while fading out.
  function rowMap(oldMap, model, items, keyOf) {
    var m = {}
    var cur = modelKeys(model)
    for (var i = 0; i < cur.length; i++) if (oldMap[cur[i]]) m[cur[i]] = oldMap[cur[i]]
    for (var j = 0; j < items.length; j++) m[keyOf(items[j])] = items[j]
    return m
  }
  function pluginKey(p) { return p.id }
  function syncPkgs() {
    pkgMap = rowMap(pkgMap, pkgModel, shown, pkgKey)
    syncModel(pkgModel, shown.map(pkgKey))
  }
  function syncPlugins() {
    // Every plugin, not just the shown ones, so a status change re-renders its row.
    pluginMap = rowMap(pluginMap, pluginModel, ctl ? ctl.pluginUpdates : [], pluginKey)
    syncModel(pluginModel, shownPlugins.map(pluginKey))
  }
  onShownChanged: syncPkgs()
  onShownPluginsChanged: syncPlugins()
  Component.onCompleted: { syncPkgs(); syncPlugins() }

  // Sections fade in as they appear, and the ones below slide to make room.
  add: Transition {
    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.duration(180); easing.type: Easing.OutCubic }
  }
  move: Transition {
    NumberAnimation { property: "y"; duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    NumberAnimation { property: "opacity"; to: 1; duration: Style.duration(180) }
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
        text: "UPDATES"
        color: view.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        font.letterSpacing: Style.space(1.5)
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        elide: Text.ElideRight
        text: view.ctl && view.ctl.agoText() !== "" && !view.ctl.checking && !view.ctl.pluginChecking
          ? view.ctl.agoText() : "Arch · Omarchy · AUR · Plugins"
        color: view.fg
        opacity: 0.7
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
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
      enabled: view.phase !== "checking" && !(view.ctl && view.ctl.pluginChecking)
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
      opacity: view.phase !== "pending" ? 1 : 0
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
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
        Behavior on color { ColorAnimation { duration: Style.duration(180) } }
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        RotationAnimator on rotation {
          running: view.phase === "checking" && view.visible && !Style.reduceMotion
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
        // Each source ticks off as its check finishes.
        Row {
          visible: view.phase === "checking"
          spacing: Style.space(12)
          SourceChip {
            label: "Arch"
            done: !!view.ctl && view.ctl.archDone
            tint: view.ctl ? view.ctl.repoColor("arch") : view.fg
          }
          SourceChip {
            label: "Omarchy"
            done: !!view.ctl && view.ctl.archDone
            tint: view.ctl ? view.ctl.repoColor("omarchy") : view.fg
          }
          SourceChip {
            label: "AUR"
            done: !!view.ctl && view.ctl.aurDone
            tint: view.ctl ? view.ctl.repoColor("aur") : view.fg
          }
          SourceChip {
            label: !view.ctl || !view.ctl.pluginChecking || view.ctl.pluginFetchTotal === 0 ? "Plugins"
              : "Plugins " + view.ctl.pluginFetchDone + "/" + view.ctl.pluginFetchTotal
            done: !!view.ctl && !view.ctl.pluginChecking
            tint: view.pluginTint
          }
        }
        Text {
          width: parent.width
          visible: view.phase !== "checking"
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          text: view.phase === "clean" ? (view.partial ? "Some sources could not be checked" : "Your system is up to date")
            : view.phase === "error" ? (view.ctl ? view.ctl.errorMessage : "")
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
      opacity: view.phase === "pending" ? 1 : 0
      visible: opacity > 0
      Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      width: parent.width
      implicitHeight: Math.max(countBlock.implicitHeight, legend.implicitHeight)

      Column {
        id: countBlock
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // Scrambles through random digits and settles left to right on the
        // real count (about 0.6s) whenever the count appears or changes.
        Text {
          id: bigCount
          readonly property string target: Commons.I18n.formatNumber(view.total)
          readonly property bool live: view.phase === "pending"
          property string shown: target
          property int tick: 0
          readonly property int ticks: 14

          function scramble() {
            if (Style.reduceMotion || !live) { scrambleTimer.stop(); shown = target; return }
            tick = 0
            scrambleTimer.restart()
            step()
          }
          function step() {
            var digits = String(view.total).length
            var lo = Math.pow(10, digits - 1), hi = Math.pow(10, digits) - 1
            var noise = Commons.I18n.formatNumber(lo + Math.floor(Math.random() * (hi - lo + 1)))
            if (noise.length !== target.length) { shown = target; return }
            // First third is pure noise, then digits lock in from the left.
            var settled = Math.floor(Math.max(0, tick - ticks / 3) / (ticks * 2 / 3) * target.length)
            shown = target.slice(0, settled) + noise.slice(settled)
          }

          onTargetChanged: scramble()
          onLiveChanged: if (live) scramble()

          Timer {
            id: scrambleTimer
            interval: 45
            repeat: true
            onTriggered: {
              bigCount.tick++
              if (bigCount.tick >= bigCount.ticks) { stop(); bigCount.shown = bigCount.target }
              else bigCount.step()
            }
          }

          textFormat: Text.PlainText
          text: shown
          color: view.fg
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.displayLarge * 1.6)
          font.weight: Font.ExtraBold
          font.letterSpacing: -Style.space(3)
          lineHeight: 0.9
        }
        Text {
          textFormat: Text.PlainText
          text: view.total === 1 ? "SYSTEM UPDATE PENDING" : "SYSTEM UPDATES PENDING"
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
        running: sweep.visible && view.visible && !Style.reduceMotion
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

  NoticeLine {
    visible: view.phase === "pending" && !!view.ctl && view.ctl.rebootNeeded
    glyph: "󰜉"
    message: "Includes core packages · reboot afterwards"
  }

  // ── Warnings ──────────────────────────────────────────────────────────
  Notice {
    visible: !!view.ctl && view.ctl.checked && view.partial && view.phase !== "checking"
    message: !view.ctl ? ""
      : view.ctl.aurFailed && view.ctl.archFailed ? "Arch and AUR checks failed"
      : view.ctl.aurFailed ? "AUR check failed · AUR updates are not shown"
      : "Arch check failed · Arch and Omarchy updates are not shown"
  }

  Skeleton {
    visible: view.phase === "checking"
    rows: 4
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
      // At most 8 rows; more scroll with the wheel.
      height: Math.min(contentHeight, Style.space(30) * 8)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      model: pkgModel
      add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.duration(180); easing.type: Easing.OutCubic }
      }
      remove: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Style.duration(120); easing.type: Easing.OutCubic }
      }
      displaced: Transition {
        NumberAnimation { property: "y"; duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
        NumberAnimation { property: "opacity"; to: 1; duration: Style.duration(180) }
      }
      Behavior on height { NumberAnimation { duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }

      delegate: Rectangle {
        id: rowItem
        required property string key
        required property int index
        readonly property var modelData: view.pkgMap[key] || ({ source: "", name: "", from: "", to: "" })
        readonly property color tint: view.ctl ? view.ctl.repoColor(modelData.source) : view.fg
        readonly property bool core: view.ctl ? view.ctl.isCorePackage(modelData.name) : false

        width: ListView.view.width
        height: Style.space(30)
        radius: view.radius
        color: rowMouse.containsMouse ? Util.alpha(tint, 0.1)
          : index % 2 === 1 ? Util.alpha(view.fg, 0.025) : "transparent"
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }

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

        VersionPair {
          id: versions
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          from: rowItem.modelData.from
          to: rowItem.modelData.to
          tint: rowItem.tint
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
    text: view.total === 1 ? "Install 1 system update" : "Install " + Commons.I18n.formatNumber(view.total) + " system updates"
    onClicked: if (view.ctl) view.ctl.runUpdate()
  }

  // ── Plugins ───────────────────────────────────────────────────────────
  Item {
    width: parent.width
    height: Style.space(8) + 1
    PanelSeparator { anchors.bottom: parent.bottom; foreground: view.fg }
  }

  Item {
    id: pluginSection
    readonly property int n: view.ctl ? view.ctl.pluginTotal - view.ctl.pluginLocalCount : 0
    readonly property int hidden: view.ctl ? view.ctl.pluginLocalCount : 0
    onHiddenChanged: if (hidden === 0) view.showLocal = false
    readonly property bool checking: view.ctl ? view.ctl.pluginChecking : false
    readonly property bool checked: view.ctl ? view.ctl.pluginCheckedMs > 0 : false
    width: parent.width
    height: Math.max(pluginHeader.implicitHeight, hiddenToggle.implicitHeight)

    Row {
      id: pluginHeader
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "PLUGINS"
        color: view.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: Style.space(1.5)
      }

      // Count pill, like the legend counts above.
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: pluginSection.n > 0 && !pluginSection.checking
        width: pillText.implicitWidth + Style.space(12)
        height: pillText.implicitHeight + Style.space(2)
        radius: height / 2
        color: Util.alpha(view.pluginTint, 0.16)
        Text {
          id: pillText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: Commons.I18n.formatNumber(pluginSection.n)
          color: view.pluginTint
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    // Status when there is nothing to list, or while fetching.
    Row {
      anchors.right: hiddenToggle.visible ? hiddenToggle.left : parent.right
      anchors.rightMargin: hiddenToggle.visible ? Style.space(4) : Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      visible: pluginSection.checking || pluginSection.n === 0
      spacing: Style.space(6)
      Text {
        id: pluginGlyph
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: pluginSection.checking ? "󰓦" : pluginSection.checked ? "󰗡" : "󰐱"
        color: pluginSection.checking ? view.pluginTint
          : pluginSection.checked ? (view.ctl ? view.ctl.paletteColor("green", Commons.Color.accent) : Commons.Color.accent)
          : view.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        RotationAnimator on rotation {
          running: pluginSection.checking && view.visible && !Style.reduceMotion
          from: 0; to: 360
          duration: 1400
          loops: Animation.Infinite
          onRunningChanged: if (!running) pluginGlyph.rotation = 0
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: pluginSection.checking
          ? (view.ctl && view.ctl.pluginFetchTotal > 0
             ? "Fetching " + view.ctl.pluginFetchDone + " of " + view.ctl.pluginFetchTotal + "…" : "Fetching…")
          : pluginSection.checked && pluginSection.hidden > 0 ? "Nothing to install"
          : pluginSection.checked ? "All up to date"
          : "Not checked yet"
        color: view.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    // Reveals plugins with local changes, which can't be fast-forwarded.
    PanelActionButton {
      id: hiddenToggle
      anchors.right: parent.right
      // Line up with the rows' install buttons (list inset + row margin).
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      visible: pluginSection.hidden > 0
      iconText: view.showLocal ? "󰈉" : "󰈈"
      foreground: view.showLocal ? Commons.Color.accent : view.muted
      hoverColor: Commons.Color.accent
      tooltipText: (pluginSection.hidden === 1 ? "1 plugin with local changes"
          : Commons.I18n.formatNumber(pluginSection.hidden) + " plugins with local changes")
        + (view.showLocal ? " · click to hide" : " hidden · click to show")
      onClicked: view.showLocal = !view.showLocal
    }
  }

  // Determinate progress while plugin repos are fetched.
  Item {
    width: parent.width
    height: Style.space(3)
    visible: pluginSection.checking
    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: Util.alpha(view.fg, 0.08)
    }
    Rectangle {
      height: parent.height
      radius: height / 2
      color: view.pluginTint
      width: view.ctl && view.ctl.pluginFetchTotal > 0
        ? Math.max(height, parent.width * view.ctl.pluginFetchDone / view.ctl.pluginFetchTotal) : height
      Behavior on width { NumberAnimation { duration: Style.duration(240); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }
    }
  }

  Skeleton {
    visible: pluginSection.checking && view.shownPlugins.length === 0
    rows: 2
  }

  // Plugins that could not be fetched.
  NoticeLine {
    visible: !!view.ctl && view.ctl.pluginErrors.length > 0 && !view.ctl.pluginChecking
    message: view.ctl ? "Couldn't reach " + view.ctl.pluginErrors.join(", ") + " · not shown" : ""
    tone: view.danger
  }

  Rectangle {
    width: parent.width
    visible: view.shownPlugins.length > 0
    height: pluginList.height + Style.space(8)
    radius: view.radius
    color: Util.alpha(view.fg, 0.03)
    border.width: 1
    border.color: Util.alpha(view.fg, 0.08)

    ListView {
      id: pluginList
      // Older results stay visible but dimmed while they're being refreshed.
      // (On the list, not its box: the column's transitions animate the box's opacity.)
      opacity: pluginSection.checking ? 0.45 : 1
      Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      x: Style.space(4)
      y: Style.space(4)
      width: parent.width - Style.space(8)
      // At most 4 rows; more scroll with the wheel.
      height: Math.min(contentHeight, Style.space(30) * 4)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      model: pluginModel
      add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.duration(180); easing.type: Easing.OutCubic }
      }
      remove: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Style.duration(120); easing.type: Easing.OutCubic }
      }
      displaced: Transition {
        NumberAnimation { property: "y"; duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
        NumberAnimation { property: "opacity"; to: 1; duration: Style.duration(180) }
      }
      Behavior on height { NumberAnimation { duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }

      delegate: Rectangle {
        id: pluginRow
        required property string key
        required property int index
        readonly property var modelData: view.pluginMap[key] || ({ id: key, name: "", from: "", to: "", commits: 0, status: "pending" })
        readonly property string st: modelData.status
        readonly property bool stuck: st === "blocked" || st === "diverged"
        readonly property color tint: st === "failed" ? view.danger : stuck ? view.muted : view.pluginTint

        width: ListView.view.width
        height: Style.space(30)
        radius: view.radius
        color: pluginMouse.containsMouse ? Util.alpha(tint, 0.1)
          : index % 2 === 1 ? Util.alpha(view.fg, 0.025) : "transparent"
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }

        MouseArea { id: pluginMouse; anchors.fill: parent; hoverEnabled: true }

        Rectangle {
          id: pluginStrip
          anchors.left: parent.left
          anchors.leftMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(3)
          height: Style.space(14)
          radius: width / 2
          color: pluginRow.tint
          Behavior on color { ColorAnimation { duration: Style.duration(180) } }
        }

        Text {
          anchors.left: pluginStrip.right
          anchors.leftMargin: Style.space(10)
          anchors.right: pluginDetail.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          elide: Text.ElideRight
          text: pluginRow.modelData.name
          color: pluginRow.stuck ? view.muted : view.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        // Versions while pending; a status line otherwise.
        Item {
          id: pluginDetail
          anchors.right: action.left
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          width: pluginRow.st === "pending" ? pendingDetail.implicitWidth : statusDetail.implicitWidth
          height: Math.max(pendingDetail.implicitHeight, statusDetail.implicitHeight)

          Row {
            id: pendingDetail
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: pluginRow.st === "pending"
            spacing: Style.space(8)
            VersionPair {
              anchors.verticalCenter: parent.verticalCenter
              from: pluginRow.modelData.from
              to: pluginRow.modelData.to
              tint: pluginRow.tint
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: pluginRow.modelData.commits > 0
              textFormat: Text.PlainText
              text: "+" + Commons.I18n.formatNumber(pluginRow.modelData.commits)
              color: view.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
          Text {
            id: statusDetail
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: pluginRow.st !== "pending"
            textFormat: Text.PlainText
            text: pluginRow.st === "updating" ? "Installing…"
              : pluginRow.st === "failed" ? "Install failed · retry"
              : pluginRow.st === "blocked" ? "Local changes · update manually"
              : pluginRow.st === "diverged" ? "Local commits · update manually"
              : ""
            color: pluginRow.st === "updating" ? view.muted : pluginRow.tint
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Item {
          id: action
          anchors.right: parent.right
          anchors.rightMargin: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter
          width: actionButton.implicitWidth
          height: actionButton.implicitHeight

          PanelActionButton {
            id: actionButton
            anchors.fill: parent
            opacity: pluginRow.st !== "updating" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }
            enabled: !pluginRow.stuck
            iconText: pluginRow.st === "failed" ? "󰑐" : pluginRow.stuck ? "󰀪" : "󰇚"
            foreground: pluginRow.st === "pending" ? view.fg : pluginRow.tint
            hoverColor: pluginRow.tint
            tooltipText: pluginRow.st === "failed" ? "Retry install"
              : pluginRow.modelData.commits > 0 ? "Install update · " + (pluginRow.modelData.commits === 1 ? "1 new commit"
                  : Commons.I18n.formatNumber(pluginRow.modelData.commits) + " new commits")
              : "Install update"
            onClicked: if (view.ctl) view.ctl.updatePlugins([pluginRow.modelData.id])
          }

          Text {
            id: rowSpinner
            anchors.centerIn: parent
            opacity: pluginRow.st === "updating" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }
            textFormat: Text.PlainText
            text: "󰓦"
            color: pluginRow.tint
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
            RotationAnimator on rotation {
              running: rowSpinner.visible && view.visible && !Style.reduceMotion
              from: 0; to: 360
              duration: 1200
              loops: Animation.Infinite
              onRunningChanged: if (!running) rowSpinner.rotation = 0
            }
          }
        }
      }
    }
  }

  Button {
    width: parent.width
    visible: pluginSection.n > 0
    enabled: !!view.ctl && view.ctl.pluginUpdatable.length > 0 && !view.ctl.pluginChecking
    bordered: true
    iconText: view.ctl && view.ctl.pluginBusy ? "󰓦" : "󰇚"
    iconSpinning: !!view.ctl && view.ctl.pluginBusy
    text: !view.ctl ? ""
      : view.ctl.pluginBusy && view.ctl.pluginUpdatable.length === 0 ? "Installing plugin updates…"
      : view.ctl.pluginUpdatable.length === 1 ? "Install 1 plugin update"
      : "Install " + Commons.I18n.formatNumber(view.ctl.pluginUpdatable.length) + " plugin updates"
    onClicked: if (view.ctl) view.ctl.updateAllPlugins()
  }
}
