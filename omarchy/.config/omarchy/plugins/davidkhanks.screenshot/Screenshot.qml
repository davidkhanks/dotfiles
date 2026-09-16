import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "davidkhanks.screenshot"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-fa-camera
    text: ""
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "Screenshot — click: region, right-click: fullscreen"
    // WidgetButton already accepts left/right/middle and emits
    // pressed(int button); no acceptedButtons property exists here.
    onPressed: function(button) {
      if (button === Qt.RightButton)
        root.bar.run("omarchy-capture-screenshot fullscreen")
      else
        root.bar.run("omarchy-capture-screenshot region")
    }
  }
}
