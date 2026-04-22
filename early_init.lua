-- ~/.config/nvim/user_pre.lua
-- Gitignored

-- Example: change leader key before loading keymaps
vim.g.mapleader = " "

vim.cmd("colorscheme gruvbox8")

-- Example: Feature toggles (users can set these in early_init.lua)
vim.g.purevim_features = {
	-- colorscheme = false, -- disable colorscheme
	-- dashboard = false, -- disable dashboard
	-- fzf = { -- configure FZF or set to false to disable
	-- 	position = "bottom",
	-- 	width_ratio = 1,
	-- 	height_ratio = 0.3,
	-- 	border = "none",
	-- },
	-- lsp = false, -- disable LSP
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
