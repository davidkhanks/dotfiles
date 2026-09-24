import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// A lock button that hides and reveals with the rest of the centre-section
// indicators (StayAwake's coffee mug and friends).
//
// It is NOT a BarIndicator, even though it behaves like one. BarIndicator gets
// its reveal state from `indicatorHost.revealInactiveIndicators`, and only the
// omarchy.indicators widget can be that host -- a standalone plugin has no
// host, so `inactiveRevealed` would never become true.
//
// Extending omarchy.indicators instead was the other option: its entry list is
// configurable, but ids resolve to `../indicators/<id>.qml` under
// /usr/share/omarchy, so a user entry would need its QML inside an
// Omarchy-owned directory. Cloning the whole widget would work and would also
// fork it away from upstream updates.
//
// So this reads the same bar-level hover flag the real indicators read
// (`bar.centerSectionRevealHeld`, published on the bar API by Bar.qml) and
// mirrors their opacity: 0 when idle, 0.45 when the centre section is hovered.
// Width is held constant rather than collapsed, matching the indicators, so
// revealing does not shove the clock sideways.
BarWidget {
  id: root
  moduleName: "davidkhanks.lock"

  readonly property bool sectionRevealed:
    !!root.bar && root.bar.centerSectionRevealHeld === true
                && root.bar.centerHoverRevealSuppressed !== true

  // Hovering the widget itself keeps it up, the way indicatorItemHovered does.
  property bool selfHovered: false
  readonly property bool revealed: sectionRevealed || selfHovered

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  opacity: revealed ? 0.45 : 0
  Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

  HoverHandler {
    onHoveredChanged: root.selfHovered = hovered
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-md-lock (U+F033E) -- Material Design range, matching StayAwake's
    // coffee mug (U+F0176) rather than the Font Awesome set.
    text: "󰌾"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "Lock — click: lock now, right-click: system menu"
    onPressed: function(button) {
      if (button === Qt.RightButton)
        root.bar.run("omarchy-menu toggle system")
      else
        root.bar.run("omarchy-system-lock")
    }
  }
}
