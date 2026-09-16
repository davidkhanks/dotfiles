-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Slow the pointer slightly. Range is -1.0 to 1.0, 0 is Hyprland's default.
-- Applies to every pointing device; the device blocks below exempt the
-- laptop trackpad, which is already slow enough at 0.
hl.config({
  input = {
    sensitivity = -0.3,
  },
})

-- Per-device override: the built-in trackpad keeps Hyprland's default speed
-- while external mice stay slowed by the global setting above. A device block
-- wins over input.sensitivity for that device only.
--
-- Names come from `hyprctl devices` (the "mice:" section), lowercased with
-- spaces as dashes. Both PIXA3854 nodes are the same physical trackpad -- the
-- chip exposes a touchpad node and a mouse-emulation node, and which one
-- delivers motion depends on how libinput binds it, so set both.
-- A device block for a name that is not present is simply inert, so this stays
-- harmless when the laptop is docked or the trackpad is disabled.
--
-- ---------------------------------------------------------------------------
-- Trackpad acceleration curve
-- ---------------------------------------------------------------------------
-- libinput's three profiles, for the trackpad only (mice keep the default
-- "adaptive", because input.accel_profile above is left unset):
--
--   adaptive  libinput's default. Decelerates at low speed, which is what
--             read as drag/lag.
--   flat      strictly 1:1. Direct, but no reach -- crossing the screen
--             needs a full swipe. Kept below as TRACKPAD_ACCEL_FLAT.
--   custom    a curve we define. Used here.
--
-- Syntax is "custom <step> <p0> <p1> ...". The points are OUTPUT speed, not
-- multipliers, both axes in device units per millisecond, so the gain at any
-- speed is p/x. Points sit at 0*step, 1*step, 2*step...; libinput linearly
-- interpolates between them and extrapolates the last two beyond the end.
-- That means "flat" is exactly "custom 1.0 0.0 1.0".
--
-- Damped at the bottom for precision, ramping to roughly 3x so fast swipes
-- still cross the screen. macOS accelerates on a curve of this shape rather
-- than a straight line, which is why flat felt slow:
--
--   input speed   0     2     4     6     8    10     16      20
--   output        0    1.2   4.4  10.2   17    25     49      65
--   gain          -   0.60x 1.10x 1.70x 2.1x  2.5x   3.06x   3.25x
--
-- Note gain < 1 at the low end: a slow finger moves the cursor LESS than 1:1.
-- That is the fix for a pointer that feels squirrely when placing it exactly,
-- and it is what flat could not do -- flat is 1.0x everywhere by definition.
--
-- To tune:
--   too squirrely / hard to place precisely  -> lower p1 (and p2)
--   not enough reach on a fast swipe         -> raise the last two points
--   ramp arrives too early or too late       -> change the step
-- Keep the points increasing and their gaps growing, or the curve will feel
-- like it stalls partway through a swipe.
local TRACKPAD_ACCEL_MACOS = "custom 2.0 0.0 1.2 4.4 10.2 17.0 25.0"

-- Pinned for comparison -- swap the name on the accel_profile line below.
local TRACKPAD_ACCEL_FLAT = "flat" ---@diagnostic disable-line: unused-local

-- Scroll gets its own curve. libinput's custom profile holds SEPARATE curves
-- for pointer motion and for scrolling; supply only one and scrolling inherits
-- the pointer curve. Left unset, the aggressive ramp above was being applied to
-- scroll too -- damping slow scrolls to 0.6x and flinging fast ones past 3x,
-- which reads as choppy. "1.0 0.0 1.0" is a straight 1:1 line: no scroll
-- acceleration at all, the finger distance maps to a fixed scroll distance.
-- Overall scroll magnitude is a different knob (touchpad.scroll_factor, 0.4
-- from Omarchy) and is deliberately left alone here.
local TRACKPAD_SCROLL_LINEAR = "1.0 0.0 1.0"

for _, name in ipairs({
  "pixa3854:00-093a:1343-touchpad",
  "pixa3854:00-093a:1343-mouse",
}) do
  hl.device({
    name          = name,
    sensitivity   = 0,
    accel_profile = TRACKPAD_ACCEL_MACOS,
    scroll_points = TRACKPAD_SCROLL_LINEAR,
  })
end

-- Tap-to-click off: press the pad to click instead of resting fingers on it.
--
-- Four fingers never land or lift at exactly the same instant, so libinput
-- briefly sees a 1-3 finger contact and its tap detector fires a button press.
-- Hyprland 0.56 does its own trackpad gesture handling (CTrackpadGestures),
-- which runs independently of libinput's tap machine, so the stray click lands
-- before the four-finger swipe is ever classified as a gesture. libinput
-- exposes no tap timeout or pressure threshold to tune, and there is no stock
-- quirk file for this trackpad (PIXA3854 / 093A:1343), so switching tapping
-- off is the only reliable fix.
--
-- tap_and_drag is left alone: it does nothing once tap_to_click is off.
-- To go back to tapping, delete this block -- the default is true.
--
-- Note the spelling: the Lua key is tap_to_click with underscores. hyprctl
-- calls the same option input:touchpad:tap-to-click with hyphens, and the
-- hyphenated form in Lua is rejected as "unknown config key".
--
-- natural_scroll here is the touchpad's own setting, not the global one:
-- input.touchpad.natural_scroll applies only to touchpads, while
-- input.natural_scroll covers mice and is deliberately left at its default.
-- So the trackpad scrolls content-follows-fingers while the mouse wheel keeps
-- the conventional orientation -- no per-device block needed.
-- scroll_factor scales how far the content moves per unit of finger travel.
-- Omarchy ships 0.4; 0.12 is under a third of that. This is magnitude, not the curve:
-- scroll_points above keeps the response linear, this sets how much of it you
-- get. Touchpad only -- a mouse wheel is unaffected.
--
-- Note Omarchy also applies per-window multipliers on top of this
-- (see $OMARCHY_PATH/default/hypr/input.lua): 1.5x in Alacritty/kitty/foot and
-- 0.2x in ghostty. So a terminal still scrolls 1.5x whatever is set here.
hl.config({
  input = {
    touchpad = {
      tap_to_click = false,
      natural_scroll = true,
      scroll_factor = 0.12,
    },
  },
})

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use natural (inverse) scrolling.
--       natural_scroll = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Four-finger horizontal swipe changes workspace: swipe the fingers left to go
-- to the next workspace (1 -> 2), right to go back (2 -> 1). Three fingers are
-- left free for anything else.
--
-- Which physical direction counts as "next" is decided by
-- gestures:workspace_swipe_invert, not by this line. It defaults to true; flip
-- it below if the swipe feels backwards. The gesture is live-tracked, so the
-- workspace follows your fingers and snaps when you let go.
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

hl.config({
  gestures = {
    -- Stop at the last workspace instead of creating a new one by swiping past
    -- it, which is easy to do by accident with a live-tracked gesture.
    workspace_swipe_create_new = false,
  },
})

-- If the swipe direction feels inverted, set this to false (default: true):
-- hl.config({ gestures = { workspace_swipe_invert = false } })

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })
