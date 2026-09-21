# starship prompt for fish.
#
# The bash side of this repo gets starship from Omarchy's default/bash/rc (and,
# off Omarchy, from the guarded init in bash/.bashrc). fish had neither, so on
# a fish machine the stowed ~/.config/starship.toml was never read by anything.
#
# Guarded on starship actually being installed: this file is stowed before
# step_packages has necessarily run, and an unguarded `starship init` would
# print an error on every new shell until it was.

# --- ordering ---------------------------------------------------------------
# fish sources every conf.d directory -- the user's, the system's, and
# vendor_conf.d -- as one alphabetically ordered list. The filename is doing
# real work here: "starship.fish" sorts after "pure.fish", so if a prompt in
# vendor_conf.d ever defines fish_prompt at source time, this still wins.
# Renaming it to something sorting before "p" would silently give the prompt
# away. (Today CachyOS's fish-pure-prompt defines fish_prompt as an autoloaded
# function in vendor_functions.d instead, and autoload never fires for a
# function that is already defined, so this would win regardless -- but that is
# their implementation detail, not a guarantee.)

if type -q starship
    starship init fish | source
end
