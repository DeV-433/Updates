import QtQuick
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
  function isCorePackage(n) {
    return /^linux(-lts|-zen|-hardened|-rt|-cachyos[a-z0-9-]*)?$/.test(n)
      || /^(systemd|glibc|intel-ucode|amd-ucode)$/.test(n)
      || /^nvidia(-open|-lts|-dkms|-open-dkms|-utils)?$/.test(n)
  }
  readonly property bool rebootNeeded: {
    for (var i = 0; i < updates.length; i++) if (isCorePackage(updates[i].name)) return true
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
  function paletteColor(key, fallback) { return palette[key] ? palette[key] : fallback }
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
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    UpdatesView {
      id: content
      width: parent.width
      ctl: root
    }
  }
}
