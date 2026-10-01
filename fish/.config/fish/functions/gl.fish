# Mirror of the `gl` alias in bash/.bashrc. fish never reads .bashrc, so a
# convenience added there exists on Omarchy and silently does not on the
# CachyOS box unless it is duplicated here. fish autoloads by FILENAME, so this
# file must stay named gl.fish.
function gl --description 'git log --oneline --decorate'
    git log --oneline --decorate $argv
end
