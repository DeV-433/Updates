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
  readonly property int systemTotal: updates.length
  // Plugins with local commits or edits are hidden by default and not counted.
  readonly property int total: systemTotal + pluginTotal - pluginLocalCount

  // ── Plugins ───────────────────────────────────────────────────────────
  // State lives in a cache file written by backend/check-plugins and
  // backend/update-plugins, so it survives the plugin reload an update causes.
  property bool pluginChecking: false
  property var pluginUpdates: []
  property var pluginErrors: []
  property real pluginCheckedMs: 0
  readonly property int pluginTotal: pluginUpdates.length
  function isLocal(p) { return p.status === "diverged" || p.status === "blocked" }
  readonly property int pluginLocalCount: pluginUpdates.filter(isLocal).length
  readonly property var pluginUpdatable: pluginUpdates.filter(function(p) {
    return p.status === "pending" || p.status === "failed"
  })
  readonly property bool pluginBusy: {
    for (var i = 0; i < pluginUpdates.length; i++) if (pluginUpdates[i].status === "updating") return true
    return false
  }
  readonly property string pluginStatePath:
    (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/omarchy-updatecheck/plugins.tsv"

  function backendPath(name) {
    return String(Qt.resolvedUrl("backend/" + name)).replace(/^file:\/\//, "")
  }

  // Live progress while checking, from the backends' done/total lines.
  property bool archDone: false
  property bool aurDone: false
  property int pluginFetchTotal: 0
  property int pluginFetchDone: 0
  function scanSystemProgress(t) {
    archDone = t.indexOf("done\tarch") >= 0
    aurDone = t.indexOf("done\taur") >= 0
  }
  function scanPluginProgress(t) {
    var m = t.match(/^total\t(\d+)$/m)
    pluginFetchTotal = m ? Math.min(Number(m[1]), 1000) : 0
    var d = t.match(/^done\t/mg)
    pluginFetchDone = d ? Math.min(d.length, pluginFetchTotal) : 0
  }

  function checkPlugins() {
    if (checkPluginsProc.running || pluginBusy) return
    pluginFetchTotal = 0
    pluginFetchDone = 0
    pluginChecking = true
    checkPluginsProc.running = true
  }

  function updatePlugins(ids) {
    var valid = ids.filter(function(id) { return /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id) && id.indexOf("..") < 0 })
    if (valid.length === 0) return
    // Mark them now so the buttons react before the script's first write lands.
    pluginUpdates = pluginUpdates.map(function(p) {
      return valid.indexOf(p.id) >= 0 ? Object.assign({}, p, { status: "updating" }) : p
    })
    // Detached: pulling a plugin reloads every plugin, this one included.
    Quickshell.execDetached([backendPath("update-plugins")].concat(valid))
  }
  function updateAllPlugins() {
    updatePlugins(pluginUpdatable.map(function(p) { return p.id }))
  }

  function parsePlugins(raw) {
    var out = [], errs = [], checkedAt = 0
    var lines = String(raw).split("\n")
    for (var i = 0; i < lines.length && out.length < 500; i++) {
      var f = lines[i].split("\t")
      if (f[0] === "checked" && f.length === 2) checkedAt = Number(f[1]) * 1000 || 0
      else if (f[0] === "error" && f.length === 2) errs.push(f[1].slice(0, 100))
      else if (f[0] === "plugin" && f.length === 7
               && ["pending", "updating", "failed", "blocked", "diverged"].indexOf(f[6]) >= 0)
        out.push({ id: f[1].slice(0, 100), name: f[2].slice(0, 80), from: f[3].slice(0, 40),
                   to: f[4].slice(0, 40), commits: Math.min(Number(f[5]) || 0, 99999), status: f[6] })
    }
    pluginUpdates = out
    pluginErrors = errs
    pluginCheckedMs = checkedAt
    nowMs = Date.now()
  }
  readonly property color foreground: bar ? bar.barForeground : Commons.Color.foreground

  function count(src) {
    var n = 0
    for (var i = 0; i < updates.length; i++) if (updates[i].source === src) n++
    return n
  }

  function open() {
    nowMs = Date.now()
    root.controller.show()
    Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
  }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function closeForPopoutSwitch() { root.close() }

  // Packages whose upgrade needs a reboot to take full effect.
  function isCorePackage(n) {
    return /^linux(-lts|-zen|-hardened|-rt|-omarchy|-cachyos[a-z0-9-]*)?(-headers)?$/.test(n)
      || /^(systemd|glibc|intel-ucode|amd-ucode|hyprland)$/.test(n)
      || /^nvidia(-open|-lts|-dkms|-open-dkms|-utils)?$/.test(n)
  }
  readonly property bool rebootNeeded: {
    for (var i = 0; i < updates.length; i++) if (isCorePackage(updates[i].name)) return true
    return false
  }

  // Covers both sections: the most recent of the system and plugin checks.
  function agoText() {
    var last = Math.max(lastCheckedMs, pluginCheckedMs)
    if (last <= 0) return ""
    var m = Math.floor((nowMs - last) / 60000)
    if (m < 1) return "Checked just now"
    if (m < 60) return "Checked " + m + " min ago"
    var h = Math.floor(m / 60)
    return "Checked " + h + (h === 1 ? " hour ago" : " hours ago")
  }

  function check() {
    checkPlugins()
    if (checkProc.running) return
    errorMessage = ""
    archDone = false
    aurDone = false
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
    running: root.opened && (root.lastCheckedMs > 0 || root.pluginCheckedMs > 0)
    onTriggered: root.nowMs = Date.now()
  }

  Process {
    id: checkProc
    command: [root.backendPath("check-updates")]
    stdout: StdioCollector {
      waitForEnd: false
      onDataChanged: root.scanSystemProgress(text)
      onStreamFinished: root.updates = root.parse(text)
    }
    onExited: function(code) {
      root.checking = false
      if (code !== 0) { root.errorMessage = "Could not check for updates"; root.updates = [] }
      else { root.checked = true; root.lastCheckedMs = Date.now(); root.nowMs = root.lastCheckedMs }
    }
  }

  FileView {
    id: pluginState
    path: root.pluginStatePath
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.parsePlugins(text())
    onLoadFailed: root.parsePlugins("")
  }

  // The update script replaces the file with mv, which a watch can miss, so
  // poll as well while an update is running.
  Timer {
    interval: 1000
    repeat: true
    running: root.pluginBusy
    onTriggered: pluginState.reload()
  }

  Process {
    id: checkPluginsProc
    command: [root.backendPath("check-plugins")]
    stdout: StdioCollector {
      waitForEnd: false
      onDataChanged: root.scanPluginProgress(text)
    }
    onExited: { root.pluginChecking = false; pluginState.reload() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
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
