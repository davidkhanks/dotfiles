-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- Tighten both gaps to 4 visible pixels (Omarchy ships 10 and 5).
--
-- The two are not measured the same way, which is why the numbers differ:
--   gaps_out is the whole margin from a window to the screen edge, so 4 -> 4px.
--   gaps_in is applied to EACH window's edge, so the space between two
--   neighbours is 2 x gaps_in. Omarchy's 5 is what shows up as the 10px
--   between windows; 2 gives 4.
--
-- Borders sit outside the geometry Hyprland reports, so `hyprctl clients`
-- shows 2 x border_size (4px) more than the eye sees: a 4px visual gap reads
-- as 8 between window origins.
hl.config({
  general = {
    gaps_out = 4,
    gaps_in = 2,
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
hl.config({
  decoration = {
    -- Use round window corners.
    rounding = 6,
    rounding_power = 4,
  },
})

-- hl.config({
--   decoration = {
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Keep the SSH askpass PIN prompt visible as a centred modal. It appears the
-- moment the YubiKey is replugged (see yubikey-ssh-reload.service), so `pin`
-- keeps it on screen across workspace switches.
o.window({ class = "^(lxqt-openssh-askpass)$" }, { "float", "center", "pin" })
