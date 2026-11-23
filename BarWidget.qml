import QtQuick
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "io.github.devanshu.updatecheck"

  readonly property int total: panelLoader.item ? panelLoader.item.total : 0
  readonly property bool checking: panelLoader.item ? (panelLoader.item.checking === true || panelLoader.item.pluginChecking === true
       || panelLoader.item.pluginBusy === true) : false

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.settings = root.settings
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.checking ? "󰓦" : "󰁉"
    textRotation: spin.running ? spinAngle : 0
    property real spinAngle: 0
    slotSize: Style.bar.statusSlot
    tooltipText: root.checking ? "Checking for updates…"
      : root.total > 0 ? root.total + (root.total === 1 ? " update available" : " updates available")
      : "Check for updates"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }

    NumberAnimation on spinAngle {
      id: spin
      running: root.checking && !Style.reduceMotion
      from: 0; to: 360
      duration: 1200
      loops: Animation.Infinite
    }
  }
}
