# PureVim - A Plugin-free Neovim Configuration

A clean, efficient Neovim configuration built **only on what ships with
Neovim**: no plugins, no plugin manager and no "internal plugins" wrapping
external TUIs. The only hard external dependency is `git` (for the git
features); everything else (ripgrep, lazygit, usql, LSP servers, formatters)
is optional and picked up when it is installed.

<img width="1912" height="1017" alt="image" src="https://github.com/user-attachments/assets/dc70f57b-cd79-42ae-87ef-21a07ca8c118" />

## Performance

This configuration is designed to be lightweight and fast:

- No external plugins
- Lazy redraw enabled
- Optimized updatetime
- Efficient autocommands

## Features

- [x] Intuitive keymaps
- [x] Native LSP support
  - [x] Go to definition: `gd`
  - [x] Show documentation: `K`
  - [x] Rename symbol: `<leader>rn`
  - [x] Code actions: `<leader>ca`
  - [x] Autocomplete
- [x] Useful autocommands
  - [x] Diagnostics float mouse hover
  - [x] autoformat
- [x] Fuzzy file finder: `:find` + `findfunc` + `matchfuzzy`, with cmdline
      autocompletion as you type (`<leader>ff`)
- [x] Project grep into the quickfix list: `:PureGrep` (`<leader>fg`,
      `<leader>fG` for word under cursor), refine with `:Cfilter` / `:Cfuzzy`
- [x] Preview quickfix entries with `p` (keeps the focus on the list)
- [x] Git signs computed in-process with `vim.text.diff` (update while typing),
      hunk navigation `]c` / `[c`
- [x] Inline git blame (`<leader>gb`), annotate (`<leader>ga`), diff
      (`<leader>gd` / `<leader>gD`), status in quickfix (`<leader>gs`)
- [x] Native LSP configs in `lsp/` enabled with `vim.lsp.enable`
- [x] Native tree-sitter highlighting and folding

## TODOs

- [ ] Look for TODOs in the code
- [ ] Document how to install tree-sitter libraries
- [ ] Document how to install supported LSP servers
- [x] Document how to add new LSP servers: create `lsp/<name>.lua` returning
      a `vim.lsp.Config` (`cmd`, `filetypes`, `root_markers`, `settings`) and add
      `<name>` to `lsp = { servers = { ... } }` in `early_init.lua`
- [ ] Document how to "auto complete"
- [ ] Document default bindings
- [ ] Customize auto-format functions
- [ ] Generalize symbols for errors, warnings, info to be global

## Requirements

- Neovim >= 0.12.0
- A terminal with true color support
- A [Nerd Font](https://www.nerdfonts.com/) installed and set as your terminal font (required for dashboard icons)
  - [JetBrainsMono Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases/latest) is recommended (used in screenshots)
  - Quick installer: [nerd-installer](https://github.com/LionyxML/nerd-installer)
- git

Optional (used automatically when installed):

- LSP servers for your languages
- [ripgrep](https://github.com/BurntSushi/ripgrep) — faster `:grep`
  (falls back to `grep`)
- [Lazygit](https://github.com/jesseduffield/lazygit) — `<leader>gL`
  (falls back to `:PureGitStatus`)
- [usql](https://github.com/xo/usql) — `:PureSqlConnect`
- formatters configured in the `format` feature (prettier, stylua, ...)

## Installation

You can install PureVim in three different ways, depending on how much control
or automation you prefer:

1 - With Nix — for a fully reproducible environment. 2 - With a helper script —
for quick setup and dependency checking. 3 - Manually (Purist way) — for full
control, no scripts or Nix.

### 1. Installation with Nix

This configuration uses [Nix](https://nixos.org/) with
[Flakes](https://nixos.wiki/wiki/Flakes) to provide a reproducible environment
with all necessary dependencies.

**Step 1. Install Nix**

First, [install Nix](https://nixos.org/download.html) on your system and
[enable Flakes](https://nixos.wiki/wiki/Flakes#Enable_flakes).

**Step 2. Clone the Repository**

Clone this repository to your Neovim configuration directory:

```bash
# Backup your existing config first if you have one
# mv ~/.config/nvim ~/.config/nvim.backup

git clone https://github.com/carl0xs/purevim.git ~/.config/nvim
```

**Step 3. Launch the Environment**

Navigate to the configuration directory and run `nix develop`. This will launch
a shell with Neovim and all the pre-configured language servers
(`rust-analyzer`, `lua-language-server`, `typescript-language-server`)
available in your `PATH`.

```bash
cd ~/.config/nvim && nix develop
```

Now, you can run `nvim` from within this shell, and everything will work out of
the box.

### 2. Installation with Helper Script

If you don’t want to use Nix, a convenience script is provided to handle the
setup and dependency checks for you.

Run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/carl0xs/purevim/master/bin/purevim | bash
```

The script will:

- Back up your existing Neovim configuration (if any) to ~/.config/nvim.backup
- Clone this repository to ~/.config/nvim
- Check for the required dependencies and alert you if something is missing
- Dependencies checked by the script:
  - nvim
  - git
  - rg (ripgrep, optional)
  - lua-language-server
  - rust-analyzer
  - typescript-language-server

### 3. Manual Installation

If you prefer a completely transparent setup — no scripts, no abstractions —
install manually:

```bash
mv ~/.config/nvim ~/.config/nvim.backup 2>/dev/null || true
git clone https://github.com/carl0xs/purevim.git ~/.config/nvim
```

Then manually ensure all dependencies are installed on your system:

- nvim (≥ 0.12.0)
- git
- optional: rg (ripgrep), lazygit, usql, lua-language-server, rust-analyzer,
  typescript-language-server

Once everything is ready, just launch Neovim:

```bash
nvim
```

And you’re good to go.

## Configuration - Optional User Files

This Neovim configuration supports **user-specific optional files** to
customize behavior without modifying the main config. All these files are
**git-ignored** by default.

If you'd like to customize **PureVim**, simply create these files in the same
folder as this config `init.lua`.

1. **`early_init.lua`** → runs first, can set globals or feature toggles. Users
   **SHOULD** customize this file.

2. **`init.lua`** → loads modules conditionally based on feature toggles. User
   should **NOT** edit this file.

3. **`post_init.lua`** → runs last, for final tweaks and personal
   customization. Users **SHOULD** customize this file.

> ⚡ If a file does not exist, it is simply skipped, and the config runs
> normally.

### 1. `early_init.lua`

- **Purpose:** Runs **before the main config**.

- **Use it for:** Setting global options, overriding defaults, changing leader
  keys, or defining feature toggles.

- **Example:**

```lua -- ~/.config/nvim/early_init.lua

-- Or change the default colorscheme (see "Colorschemes" section below)
vim.g.purevim_colorscheme = "gruvbox8"
```

You can also turn `PureVim` special features on/off, or even customize its
setup. Just comment/uncomment what you need!

```lua
vim.g.purevim_features = {
	-- dashboard = false, -- disable dashboard
	-- git = { signs = { staged = { add = "│", change = "│", delete = "_" } } },
	-- lsp = { servers = { "lua_ls", "ts_ls" } }, -- or false to disable LSP
	-- lazygit = false, -- disable lazygit
}
```

### 2. `init.lua`

This file orchestrates how everything is loaded with `PureVim`. **DO NOT** use
this to add your own configs. Instead use `early_init.lua` or `post_init.lua`.

### 3. `post_init.lua`

- **Purpose:** Runs **after all core modules** have loaded.
- **Use it for:** Adding personal keymaps, tweaks, custom autocommands, or
  modifying highlights after the colorscheme.
- **Example:**

```lua -- ~/.config/nvim/post_init.lua

-- Custom keymap
vim.keymap.set("n", "<leader>tt", ":split | terminal<CR>", { desc = "Open terminal" })

-- Tweak statusline colors after colorscheme
vim.api.nvim_set_hl(0, "StatusLine", { fg = "#cdd6f4", bg = "#11111b" }) vim.api.nvim_set_hl(0,
    "StatusLineNC", { fg = "#a6adc8", bg = "#292c3c" })
```

## Contributing

Feel free to fork this repository and customize it to your needs. Pull requests
for improvements are welcome!

## FAQ

### Do folds work with tree-sitter?

Yes!

Here are some folding key hints:

- zc (fold)
- zo (unfold)
- zM (fold all)
- zR (unfold all)
- za (toggle current fold)

### How do I check if treesitter is turned on on my current buffer?

Focus the buffer you'd like more info to and run the command:

```
:PureCheckTreesitter
```

## License

MIT License - feel free to use and modify as you like.

---

Made with love by a Neovim enthusiast
