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

-- Canvas MFA code from the YubiKey onto the clipboard. Canvas has no passkey
-- support (TOTP only), so the seed lives in the key's OATH applet; see
-- bin/.local/bin/otp. The code lands on the clipboard -- just paste it.
-- Whether the key asks for a touch first is a property of each credential,
-- fixed when it was enrolled, and otp reads it from ykman on every call.
-- Deliberately not recorded here: that state lives on the key, changes
-- without touching this repo, and a stale claim about it is worse than no
-- claim. `ykman oath accounts add -f` re-enrols one over itself to change it.
--
-- `otp` takes the account as an argument, so another service is one more
-- bind -- but only Canvas has one, because the root menu's OTP submenu
-- already covers the rest without spending a key combination on each.
--
-- NOT SUPER + SHIFT + C, which stock Omarchy already binds to Calendar
-- (applications.lua). SUPER + ALT + C was free and keeps the C mnemonic,
-- alongside the other SUPER + ALT overrides above.
o.bind("SUPER + ALT + C", "Canvas OTP", "otp Canvas")

-- ---------------------------------------------------------------------------
-- Notifications: dismiss on the bare chord, act on ALT
-- ---------------------------------------------------------------------------
-- omarchy-settings 4.5.0 (2026-11-05, from 4.0.4) swapped these two. SUPER +
-- comma used to dismiss the last notification and now runs notifications.act,
-- which invokes or focuses when the card has anything to invoke and only
-- dismisses when it does not -- so a notification with an action opens instead
-- of going away. Dismissing is the common case here, and it should not cost an
-- extra modifier, so this puts the two chords back the way round they were.
--
-- This is a deliberate revert, not a stale copy of an old default: leave it
-- alone unless the preference changes.
--
-- Lowercase "comma" on purpose. xkbcommon names the keysym "comma" and
-- "COMMA" silently fails to match -- the stock file carries the same warning.
--
-- No comma inside a description either: the keybindings menu truncates at the
-- first one. Stock's own "Dismiss, invoke, or focus last notification" shows
-- up there as just "Dismiss", which is why this one is worded without any.
hl.unbind("SUPER + comma")
hl.unbind("SUPER + ALT + comma")
o.bind("SUPER + comma", "Dismiss last notification", { ipc = "notifications.dismissOne" })
o.bind("SUPER + ALT + comma", "Invoke or focus last notification", { ipc = "notifications.act" })

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
-- take two-finger right-click with it.
--
-- This used to bind mouse:274 to an empty Lua function, which swallowed the
-- button at the compositor (binds:pass_mouse_when_bound defaults to false).
-- That worked, but Hyprland binds carry no device field -- confirmed against
-- 0.56, whose bind objects expose modmask/key/dispatcher and nothing to scope
-- them by device -- so it also killed the middle button on the external mouse,
-- taking middle-click-to-open-link-in-new-tab with it.
--
-- The button is no longer bound. The complaint was never the click, it was the
-- primary-selection PASTE that a stray click triggers, so that is what is
-- turned off instead -- gtk-enable-primary-paste=false, set by
-- step_primary_paste in bootstrap.sh. Middle click now reaches applications:
-- a link opens in a new tab, and a stray 3-finger press does nothing.
--
-- Primary paste is per-toolkit, so anything that implements it itself rather
-- than through GTK needs its own setting; the terminals are the ones to check.
