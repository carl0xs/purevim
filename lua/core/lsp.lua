-- Native LSP (nvim >= 0.11): server configs live in `lsp/<name>.lua` on the
-- runtimepath and are picked up by `vim.lsp.enable`. Add a new server by
-- dropping a file in `lsp/` and listing its name here (or in post_init.lua).
local M = {}

M.servers = { "lua_ls", "ts_ls", "rust_analyzer" }

function M.setup(opts)
	opts = opts or {}

	vim.lsp.config("*", {
		capabilities = vim.lsp.protocol.make_client_capabilities(),
	})

	-- Only enable servers whose binary is installed, to avoid noisy errors
	local enabled = {}
	for _, name in ipairs(opts.servers or M.servers) do
		local cmd = (vim.lsp.config[name] or {}).cmd
		if type(cmd) ~= "table" or vim.fn.executable(cmd[1]) == 1 then
			table.insert(enabled, name)
		end
	end
	vim.lsp.enable(enabled)
end

return M
