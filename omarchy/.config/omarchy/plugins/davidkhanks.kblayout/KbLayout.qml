import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Toggle every keyboard between the two layouts in kb_layout ("us,us" with
// variants ",intl" -- see hypr/input.lua).
//
// WHY NOT omarchy.keyboard-layout, which does exactly this already: it has to
// decide WHICH keyboard to switch, and picks the furthest-advanced "typed"
// device. The Massdrop ALT presents four keyboard devices, and the one that
// drifts ahead is `massdrop-inc.-alt-keyboard-1`, not the
// `massdrop-inc.-alt-keyboard` that produces keystrokes. Clicking it switched
// a phantom device and nothing appeared to happen. With every device back in
// sync it instead falls through to keyboards[0], a Framework radio-control
// node -- still not the real keyboard. The heuristic cannot win here.
//
// So this switches the whole seat with `switchxkblayout all` and never names a
// device. The built-in widget avoids that deliberately, because carrying the
// button devices along breaks the furthest-advanced read it depends on -- but
// that read is exactly what this does not do. Every device moves together, so
// any of them reports the right answer.
BarWidget {
  id: root
  moduleName: "davidkhanks.kblayout"

  // Full xkb description of the current layout, e.g. "English (US)".
  property string layoutFull: ""

  // "INTL" when the dead-key variant is active, "US" otherwise. Matching on
  // the description rather than the layout index means a reordered kb_layout
  // relabels itself instead of lying.
  readonly property string label: layoutFull === "" ? "--"
    : (layoutFull.toLowerCase().indexOf("intl") !== -1 ? "INTL" : "US")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() { readProc.running = true }

  Component.onCompleted: refresh()

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      const name = String(event.name)
      // activelayout fires on every switch; configreloaded catches a change to
      // kb_layout itself, which alters what the label should say without any
      // switch having happened.
      if (name.indexOf("activelayout") !== -1 || name === "configreloaded") root.refresh()
    }
  }

  // Hyprland applies the switch to each device in turn, so a read issued the
  // instant the click returns can still catch the seat mid-move.
  Timer {
    id: settleTimer
    interval: 150
    onTriggered: root.refresh()
  }

  Process {
    id: readProc
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      id: readOut
      waitForEnd: true
      onStreamFinished: {
        var listed
        try {
          listed = JSON.parse(String(readOut.text || "{}")).keyboards
        } catch (e) {
          return
        }
        if (!Array.isArray(listed) || listed.length === 0) return
        // Every device carries the same layout because the switch is applied to
        // the whole seat, so the first one that reports a keymap speaks for all.
        for (var i = 0; i < listed.length; i++) {
          if (listed[i] && listed[i].active_keymap) {
            root.layoutFull = String(listed[i].active_keymap)
            return
          }
        }
      }
    }
  }

  Process { id: switchProc }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: root.layoutFull === "" ? "Keyboard layout"
      : "Keyboard layout: " + root.layoutFull + " — click to switch"
    onPressed: function(button) {
      switchProc.command = ["hyprctl", "switchxkblayout", "all", "next"]
      switchProc.running = true
      settleTimer.restart()
    }
  }
}
