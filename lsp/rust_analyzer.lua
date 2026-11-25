return {
	cmd = { "rust-analyzer" },
	filetypes = { "rust" },
	root_markers = { "Cargo.toml", "rust-project.json", ".git" },
	capabilities = {
		experimental = { serverStatusNotification = true },
	},
	settings = {
		["rust-analyzer"] = {
			assist = {
				importGranularity = "module",
				importPrefix = "self",
			},
			cargo = { loadOutDirsFromCheck = true },
			procMacro = { enable = true },
			diagnostics = { enable = true },
			checkOnSave = { command = "clippy" },
		},
	},
}
