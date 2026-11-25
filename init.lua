-- Main configuration Neovim
-- Author: Carlos

_G.start_time = vim.uv.hrtime()

package.path = package.path .. ";" .. vim.fn.stdpath("config") .. "/?.lua"

local later = require("utils.util").later

-- Optional user file (gitignored), see early_init.example.lua. It runs before
-- anything else: set feature toggles, globals and a `User PureVimLoaded`
-- autocmd for tweaks that must run after all modules are loaded.
local user_file = vim.fn.stdpath("config") .. "/early_init.lua"
if vim.uv.fs_stat(user_file) then
	local ok, err = pcall(dofile, user_file)
	if not ok then
		vim.notify("[PureVim] error in early_init.lua: " .. err, vim.log.levels.ERROR)
	end
end

-- Defaults that respect what the user set in early_init.lua
if vim.g.mapleader == nil then
	vim.g.mapleader = " "
end
if vim.g.maplocalleader == nil then
	vim.g.maplocalleader = vim.g.mapleader
end

-- Feature toggles (users can set these in early_init.lua)
local features = vim.g.purevim_features or {}

-- Helper to conditionally run modules
local function run_if_feat_enabled(feature, fn)
	local conf = features[feature]
	if conf == false then
		return
	end
	later(function()
		fn(conf)
	end) -- pass feature configuration if available
end

-- Core modules

later(function()
	require("core.options")
end)
later(function()
	require("core.keymaps")
end)

run_if_feat_enabled("git", function(opts)
	require("core.integrations.git").setup(opts)
end)

-- Optional modules
run_if_feat_enabled("lsp", function(opts)
	require("core.lsp").setup(opts)
end)

run_if_feat_enabled("autocmd", function()
	require("core.autocmd")
end)

run_if_feat_enabled("treesitter", function()
	require("core.treesitter")
end)

run_if_feat_enabled("search", function()
	require("core.search")
end)

run_if_feat_enabled("lazygit", function()
	require("core.integrations.lazygit")
end)

run_if_feat_enabled("statusline", function()
	require("core.statusline")
end)

run_if_feat_enabled("usql", function()
	require("core.integrations.usql")
end)

run_if_feat_enabled("dashboard", function()
	require("core.dashboard").setup()
end)

run_if_feat_enabled("format", function(opts)
	require("core.format").setup(opts)
end)

-- Modules are loaded deferred (in order), so this runs after all of them.
-- Hook user tweaks with: autocmd User PureVimLoaded
later(function()
	vim.api.nvim_exec_autocmds("User", { pattern = "PureVimLoaded", modeline = false })
end)
