# Mirror of the `gs` alias in bash/.bashrc. fish never reads .bashrc, so a
# convenience added there exists on Omarchy and silently does not on the
# CachyOS box unless it is duplicated here. fish autoloads by FILENAME, so this
# file must stay named gs.fish.
#
# Shadows /usr/bin/gs (ghostscript) at an interactive prompt only; use
# `command gs` to reach the real binary.
function gs --description 'git status'
    git status $argv
end
