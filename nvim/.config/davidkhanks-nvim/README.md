# NeoVim Setup with Lazy

Follow these steps to set up NeoVim with this config

## Install NeoVim and dependencies

Install NeoVim and ripgrep

Ripgrep is a cmdline utility that has a fantastic fuzzy finder
and it is used for some of the telescope commands to find strings.

### Mac

`brew install neovim`

`brew install ripgrep`

### Linux (Debian)

Note that as of Apr 2025 apt install uses an older version of NeoVim

It might be advisable to install homebrew on your linux install and use it to get neovim

either install neovim via apt:

`sudo apt install neovim`

or install homebrew:

`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

and then install neovim:

`brew install neovim`

install ripgrep which is used for text search across files:

`sudo apt install ripgrep`

## Put these files in the correct location on your filesystem

This directory needs to be in the correct place for it be found.

I use ~/.config/ and name this containing folder nvim.

So your completed structure will be:

`~/.config/nvim/`

where nvim is the root dir of these files.

This will cause neovim to run all of the code in here by default on startup.
If you want to use a different name, you have to tell neovim what the dir name
will be in order for it find the correct dir. You can do this with the

`NVIM_APPNAME={your-dir-name}` env var

put that before running nvim or in your .bashrc or .zshrc file.

## Overview of how this config is set up

NeoVim will immediately run the init.lua file at the root of this project.

This in turn will run the `davidkhanks.core` and `davidkhanks.lazy` files.

the `core` will run the `init.lua` file in that folder which will in turn run the
`keymaps.lua` and `options.lua` files.

keymaps will set up a lot of custom keymaps for general vim use and options
will set up various vim settings such as how to track undo changes and reloading
files that change on disk, etc.

### Running Lazy

Lazy starts and runs automatically the first time you start neovim with the new
config files in place.

`davidkhanks.lazy` will run the Lazy package manager which will install the plugins
that are configured in the plugins directory. You can see in that it will run the
`davidkhanks.plugins` which will look for a lua table in any of the files in that dir.

This will install some oft used dependencies so we don't need to explicitly install them.
The rest of the plugins are configured in their respective files.

You can see the basic format of a plugin config is to return a table `{}` that contains
the github short link and a config function. Optionally you can give a commit hash to pin
a specific version of the plugin and an event name or names on when the plugin will be loaded.
Lazy can lazyload plugins JIT (hence the name) which means you can have a lot of plugins and not
have a crazy long start time.

## Plugin rundown

Really quick rundown of what each plugin does

- Alpha: Nice start/splash screen when you open nvim
- Autopairs: when you type a char that has a pair it completes them ie `(), {}, ""`
- Colorscheme: Mine is called onedark but there are lots of different ones
- Comment: Sets up `gcc` as the code comment command. Integrated into NeoVim as of version 10 but
  I have some extras in here that I like
- Dressing: Makes some typed commands show up in a pretty box instead of the default status line
- Formatting: sets up linters for various languages and options around when they execute for formatting.
- Gitsigns: Sets up git indicators like VSCode so you can see what changes are new, changed, removed etc
- Harpoon: File pin plugin written by ThePrimeagen. Nice for quickly navigating between heavily used files
- Linting: additional linting config for running specific linters
- LuaLine: Nice status bar theming that is configurable
- Marks: A way to visually track vim marks in a file
- NeoScroll: Smooth scrolling for using <C-u>, <C-d>
- Nvim-cmp: Completion UI that is similar to VSCode
- Nvim-tree: Tree structure buffer that is similar to VSCode's.
- Surround: Pluging for altering surrounding characters on text
- Telescope: A super extensible UI plugin that is most often used for different finders (A la project files, project wide grep, buffer grep, etc)
- Todo-comments: A plugin that allows you to easily see TODOs and other related comments in a file
- Treesitter: Syntax tree plugin that is used for various other plugins
- Vim-maximizer: Allows for easier window maximization when using split windows in NeoVim
- Which-key: A plugin that uses the defined descriptions for key maps to help you know what key does what after pressing <leader>

Additionally, I have LSP related plugins in their own directory. LSP (Language Server Protocol) is what VSCode uses to parse
and understand the code in a project. It is what allows for things like jumpt to definition, etc and is used by NeoVim to
do the same thing.

- Lspconfig: The official NeoVim LSP plugin that allows for various niceties in your editing environment
- mason: an LSP specific package manager. You can install all of them manually or you can have Mason do it for you.

## Most important Plugins

To me a lot of these are just nice-to-haves but the ones that I care about the most are telescope, which let's me do various types of searching,
Nvim-tree, which I like to have to see where I am at in a project (netrw is trash in comparison IMO), and the LSP setup, and nvim-tmux-navigator.

That allows for jumping between tmux panes and nvim windows seemless by leveraging <C-h>, <C-j>, <C-k>, and <C-l>. It's companion is installed
as a tmux plugin and without it I would not be using NeoVim.

## Tmux integration

I would only recommend even using this config if you are going to do so with tmux. My tmux config is located here:
https://gist.github.com/davidkhanks/3530f1bca29cf94119fc9dadb2fbf625

The main important thing to note with the tmux config is that it installs the vim-tmux-navigator which is what allows
navigation between any tmux pane and neovim by using ctrl + h,j,k,l

The config should install the tmux plugin manager automatically after the config file is in place. It needs to be in
your home directory:

`~/.tmux.conf`

You can check that the plugin manager was installed by running:

`ls ~/.tmux/plugins/tpm`

You should see `scripts`, `bin`, and `tpm` directories

If you don't you can install it manually:

`git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`

Make sure at this point to start a new tmux session or reload the config and then press your leader (ctrl+b) and I

You should see something like:

`Installing "tmux-plugins/tpm"`

at which point you should be good.

### Tmux alternate bindings and points of interest

I have rebound a few things to make them easier to remember. To split the current pane and make a new one use:

`ctrl + b` then `|`

and to split horizontally:

`ctrl + b` then `-`

To kill a pane:

`ctrl + b` then `x`

You may notice that I have unbound and then rebound this action to `x` and that is to prevent the confirmation
from being presented every time.

To maximize the current pane use:

`ctrl + b` then `m`

and then to bring it back to it's original state simply do:

`ctrl + b` then `m`

again.
