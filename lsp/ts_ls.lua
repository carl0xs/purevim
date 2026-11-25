local inlay_hints = {
	parameterNames = { enabled = "all" },
	parameterTypes = { enabled = true },
	variableTypes = { enabled = true },
}

return {
	cmd = { "typescript-language-server", "--stdio" },
	filetypes = {
		"javascript",
		"javascriptreact",
		"javascript.jsx",
		"typescript",
		"typescriptreact",
		"typescript.tsx",
	},
	root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
	init_options = { hostInfo = "neovim" },
	settings = {
		typescript = {
			suggest = { completeFunctionCalls = true },
			inlayHints = inlay_hints,
		},
		javascript = {
			suggest = { completeFunctionCalls = true },
			inlayHints = inlay_hints,
		},
	},
}
