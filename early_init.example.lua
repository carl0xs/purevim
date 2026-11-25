-- Copy this file to `early_init.lua` (gitignored) to customize PureVim
-- without touching the tracked files:
--
--   cp early_init.example.lua early_init.lua
--
-- It runs before any PureVim module is loaded.

-- Leader keys (defaults to <Space>)
-- vim.g.mapleader = " "
-- vim.g.maplocalleader = " "

-- Feature toggles: `false` disables a feature, a table configures it
vim.g.purevim_features = {
	-- dashboard = false,
	-- lazygit = false,
	-- usql = false,
	-- explorer = { columns = { "permissions", "size", "mtime" }, skip_confirm_for_simple_edits = true },
	-- git = { signs = { staged = { add = "│", change = "│", delete = "_" } } },
	-- lsp = { servers = { "lua_ls", "ts_ls" } }, -- or false to disable LSP
	-- format = {
	-- 	typescript = { "prettier" },
	-- 	javascript = { "prettier" },
	-- 	html = { "biome" },
	-- 	rust = { "lsp" },
	-- 	ruby = { "rubocop" },
	-- 	nix = { "nixfmt" },
	-- },
}

-- Everything that must run after PureVim (keymaps, highlights, colorscheme
-- tweaks...) goes in this autocmd, fired once all modules are loaded.
vim.api.nvim_create_autocmd("User", {
	pattern = "PureVimLoaded",
	once = true,
	callback = function()
		-- vim.cmd.colorscheme("habamax")
		-- vim.keymap.set("n", "<leader>tt", ":split | terminal<CR>", { desc = "Open terminal" })
		-- vim.api.nvim_set_hl(0, "StatusLine", { fg = "#cdd6f4", bg = "#11111b" })
	end,
})
