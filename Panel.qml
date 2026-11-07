import QtQuick
// Controls is imported before qs.Ui so Button keeps resolving to the Omarchy widget.
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Panel {
  id: root
  moduleName: "io.github.devanshu.updatecheck"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool checking: false
  property bool checked: false
  property string errorMessage: ""
  property var updates: []
  property bool aurFailed: false
  property bool archFailed: false
  property real lastCheckedMs: 0
  property real nowMs: Date.now()
  readonly property int total: updates.length
  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground

  function count(src) {
    var n = 0
    for (var i = 0; i < updates.length; i++) if (updates[i].source === src) n++
    return n
  }

  function open() {
    root.controller.show()
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function closeForPopoutSwitch() { root.close() }

  // Packages whose upgrade needs a reboot to take full effect.
  readonly property bool rebootNeeded: {
    for (var i = 0; i < updates.length; i++) {
      var n = updates[i].name
      if (/^linux(-lts|-zen|-hardened|-rt|-cachyos[a-z0-9-]*)?$/.test(n)
          || /^(systemd|glibc|intel-ucode|amd-ucode)$/.test(n)
          || /^nvidia(-open|-lts|-dkms|-open-dkms|-utils)?$/.test(n)) return true
    }
    return false
  }

  function agoText() {
    if (lastCheckedMs <= 0) return ""
    var m = Math.floor((nowMs - lastCheckedMs) / 60000)
    if (m < 1) return "Checked just now"
    if (m < 60) return "Checked " + m + " min ago"
    var h = Math.floor(m / 60)
    return "Checked " + h + (h === 1 ? " hour ago" : " hours ago")
  }

  function check() {
    if (checkProc.running) return
    errorMessage = ""
    checking = true
    checkProc.running = true
  }

  // Output is untrusted: cap the count and field lengths, and every Text
  // below is PlainText.
  function parse(raw) {
    var out = []
    var lines = String(raw).split("\n")
    var aurBad = false, archBad = false
    for (var i = 0; i < lines.length && out.length < 2000; i++) {
      var f = lines[i].split("\t")
      if (f.length === 2 && f[0] === "error") {
        if (f[1] === "aur") aurBad = true
        else if (f[1] === "arch") archBad = true
        continue
      }
      if (f.length !== 4 || ["arch", "omarchy", "aur"].indexOf(f[0]) < 0) continue
      out.push({ source: f[0], name: f[1].slice(0, 100), from: f[2].slice(0, 60), to: f[3].slice(0, 60) })
    }
    aurFailed = aurBad
    archFailed = archBad
    var rank = { omarchy: 0, arch: 1, aur: 2 }
    out.sort(function(a, b) { return rank[a.source] - rank[b.source] || (a.name < b.name ? -1 : 1) })
    return out
  }

  function runUpdate() {
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"])
    root.close()
  }

  // The shell only exposes foreground/accent/urgent/muted, so read the theme's
  // palette straight from its colors.toml. Re-read on every open so a theme
  // switch shows up. Only #rrggbb values are accepted.
  property var palette: ({})
  function repoColor(src) {
    var key = src === "omarchy" ? "accent" : src === "arch" ? "magenta" : "green"
    var v = palette[key]
    return v ? v : (src === "aur" ? Commons.Color.urgent : Commons.Color.accent)
  }
  function parsePalette(raw) {
    var out = {}
    var lines = String(raw).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})"/)
      if (m) out[m[1]] = m[2]
    }
    palette = out
  }
  onOpenedChanged: if (opened) themeFile.reload()

  FileView {
    id: themeFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    printErrors: false
    onLoaded: root.parsePalette(text())
  }

  function sourceLabel(s) { return s === "aur" ? "AUR" : s === "omarchy" ? "Omarchy" : "Arch" }

  Timer {
    interval: 30000
    repeat: true
    running: root.opened && root.lastCheckedMs > 0
    onTriggered: root.nowMs = Date.now()
  }

  Process {
    id: checkProc
    command: [String(Qt.resolvedUrl("backend/check-updates")).replace(/^file:\/\//, "")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updates = root.parse(text)
    }
    onExited: function(code) {
      root.checking = false
      if (code !== 0) { root.errorMessage = "Could not check for updates"; root.updates = [] }
      else { root.checked = true; root.lastCheckedMs = Date.now(); root.nowMs = root.lastCheckedMs }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    Column {
      id: content
      width: parent.width
      spacing: Style.space(10)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          id: headerTitle
          text: "Updates"
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          visible: root.checked && !root.checking && text !== ""
          width: parent.width - headerTitle.width - parent.spacing
          anchors.baseline: headerTitle.baseline
          textFormat: Text.PlainText
          elide: Text.ElideRight
          text: root.agoText()
          color: Commons.Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: root.checking ? "Checking Arch, Omarchy and AUR…"
          : root.errorMessage !== "" ? root.errorMessage
          : !root.checked ? "Not checked yet"
          : root.total === 0 ? (root.aurFailed || root.archFailed ? "No updates found" : "Everything is up to date")
          : root.total + " updates · Omarchy " + root.count("omarchy")
            + " · Arch " + root.count("arch") + " · AUR " + root.count("aur")
        color: root.errorMessage !== "" ? Commons.Color.urgent : Commons.Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width
        visible: root.checked && (root.aurFailed || root.archFailed) && !root.checking
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: root.aurFailed && root.archFailed ? "Arch and AUR checks failed"
          : root.aurFailed ? "AUR check failed · AUR updates are not shown"
          : "Arch check failed · Arch and Omarchy updates are not shown"
        color: Commons.Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      ListView {
        id: list
        visible: root.total > 0
        width: parent.width
        height: Math.min(contentHeight, Style.space(240))
        spacing: Style.space(4)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: root.updates
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
          required property var modelData
          width: ListView.view.width
          height: row.implicitHeight

          Row {
            id: row
            width: parent.width - Style.space(8)
            spacing: Style.space(8)

            Text {
              width: parent.width - tag.width - ver.width - parent.spacing * 2
              textFormat: Text.PlainText
              text: modelData.name
              color: root.foreground
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              id: tag
              width: Style.space(56)
              textFormat: Text.PlainText
              text: root.sourceLabel(modelData.source)
              color: root.repoColor(modelData.source)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Text {
              id: ver
              width: Style.space(150)
              horizontalAlignment: Text.AlignRight
              textFormat: Text.PlainText
              text: modelData.from + " → " + modelData.to
              color: Commons.Color.muted
              elide: Text.ElideLeft
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        Button {
          width: (parent.width - parent.spacing) / 2
          height: updateButton.height
          bordered: true
          iconText: "\uf021"
          iconSpinning: root.checking
          text: root.checking ? "Checking…" : "Check now"
          enabled: !root.checking
          onClicked: root.check()
        }
        Button {
          id: updateButton
          width: (parent.width - parent.spacing) / 2
          height: root.rebootNeeded && root.total > 0 ? Style.space(54) : implicitHeight
          bordered: true
          selected: enabled
          iconText: "\uf019"
          text: "Update now"
          enabled: root.total > 0 && !root.checking
          opacity: enabled ? 1 : 0.4
          onClicked: root.runUpdate()

          Text {
            visible: root.rebootNeeded && root.total > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(6)
            textFormat: Text.PlainText
            text: "Reboot required"
            color: Commons.Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
