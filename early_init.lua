-- ~/.config/nvim/user_pre.lua
-- Gitignored

-- Example: change leader key before loading keymaps
vim.g.mapleader = " "

vim.cmd("colorscheme gruvbox8")

-- Example: Feature toggles (users can set these in early_init.lua)
vim.g.purevim_features = {
	-- colorscheme = false, -- disable colorscheme
	-- dashboard = false, -- disable dashboard
	-- git = { signs = { staged = { add = "│", change = "│", delete = "_" } } },
	-- lsp = { servers = { "lua_ls", "ts_ls" } }, -- or false to disable LSP
	-- lazygit = false, -- disable lazygit
	-- format = {
	-- 	typescript = { "prettier" },
	-- 	javascript = { "prettier" },
	-- 	html = { "biome" },
	-- 	rust = { "lsp" },
	-- 	ruby = { "rubocop" }
	-- 	nix =	 { "nixfmt" }
	-- },
}
