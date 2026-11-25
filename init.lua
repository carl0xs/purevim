-- Main configuration Neovim
-- Author: Carlos

_G.start_time = vim.uv.hrtime()

package.path = package.path .. ";" .. vim.fn.stdpath("config") .. "/?.lua"

local later = require("utils.util").later

-- Load optional early_init.lua file
pcall(require, "early_init")

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
--
run_if_feat_enabled("format", function(opts)
	require("core.format").setup(opts)
end)

-- Load optional post_init.lua file
pcall(require, "post_init")
