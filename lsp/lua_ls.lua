return {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = { "lua_ls.json", ".luarc.json", ".luarc.jsonc", ".git" },
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			diagnostics = {
				disable = { "undefined-field" },
				globals = { "vim" },
			},
			workspace = {
				checkThirdParty = false,
				library = { vim.env.VIMRUNTIME },
			},
			telemetry = { enable = false },
		},
	},
}
