-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- ---------------------------------------------------------------------------
-- Vim-style window navigation
-- ---------------------------------------------------------------------------
-- Relocate the defaults that occupied SUPER + J/K/L. The arrow-key equivalents
-- of everything below are untouched and still work.

-- Was: SUPER + J (Toggle window split)
hl.unbind("SUPER + J")
o.bind("SUPER + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))

-- Was: SUPER + K (Keybindings menu) -- SUPER + ALT/CTRL + K are the tmux and
-- herdr keybinding menus, so this lands on SHIFT + ALT.
hl.unbind("SUPER + K")
o.bind("SUPER + SHIFT + ALT + K", "Keybindings", "omarchy-menu-keybindings")

-- Was: SUPER + L (Toggle workspace layout)
hl.unbind("SUPER + L")
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- Move focus (mirrors SUPER + arrows)
o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))

-- Swap windows (mirrors SUPER + SHIFT + arrows)
o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

-- ---------------------------------------------------------------------------
-- Middle click does nothing
-- ---------------------------------------------------------------------------
-- The trackpad is a mechanical clickpad that reports only BTN_LEFT; it has no
-- BTN_RIGHT or BTN_MIDDLE in hardware. libinput's clickfinger_behavior
-- synthesises those from the finger count at the moment the switch closes:
-- 1 finger = left, 2 = right, 3 = middle. So resting three fingers while
-- pressing -- easy to do mid-swipe -- fires a middle click, and middle click
-- is primary-selection paste, which dumps text into whatever has focus.
--
-- libinput offers no way to drop just the 3-finger mapping. clickfinger_button_map
-- is not in this Hyprland build, and turning clickfinger_behavior off would
-- take two-finger right-click with it. Binding the button is the surgical
-- option: binds:pass_mouse_when_bound defaults to false, so a bound mouse
-- button is swallowed by the compositor and never reaches the application.
-- A Lua function that does nothing is the cheapest possible handler -- no
-- process is spawned, unlike an `exec true`.
--
-- CAVEAT: Hyprland binds are not per-device, so this also disables the middle
-- button on any external mouse -- including middle-click-to-close-tab and
-- middle-click-to-open-link-in-new-tab in browsers. Delete this block to get
-- both back.
hl.bind("mouse:274", function() end, { mouse = true })
