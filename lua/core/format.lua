local M = {}

M.config = {}
M.executors = {}

local function make_cmd_executor(build_cmd)
	return function(bufnr, callback)
		local filepath = vim.api.nvim_buf_get_name(bufnr)
		local stderr = {}
		vim.fn.jobstart(build_cmd(filepath), {
			stderr_buffered = true,
			on_stderr = function(_, data)
				if data then
					vim.list_extend(stderr, data)
				end
			end,
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					vim.cmd("checktime " .. bufnr)
				else
					local msg = table.concat(stderr, "\n"):match("^%s*(.-)%s*$")
					if msg ~= "" then
						vim.notify("[format] " .. msg, vim.log.levels.WARN)
					end
				end
				callback(exit_code)
			end,
		})
	end
end

M.executors.prettier = make_cmd_executor(function(f)
	return { "prettier", "--write", f }
end)
M.executors.biome = make_cmd_executor(function(f)
	return { "biome", "format", "--write", f }
end)
M.executors.shfmt = make_cmd_executor(function(f)
	return { "shfmt", "-w", f }
end)
M.executors.stylua = make_cmd_executor(function(f)
	return { "stylua", f }
end)
M.executors.ruff = make_cmd_executor(function(f)
	return { "ruff", "format", f }
end)
M.executors.gofmt = make_cmd_executor(function(f)
	return { "gofmt", "-w", f }
end)
M.executors.rubocop = make_cmd_executor(function(f)
	return { "rubocop", "-a", "--no-color", f }
end)
M.executors.nixfmt = make_cmd_executor(function(f)
	return { "nix", "fmt", f }
end)

M.executors.lsp = function(bufnr, callback)
	vim.lsp.buf.format({ bufnr = bufnr, async = false })
	callback(0)
end

local function resolve_formatter(filetype)
	local ft_config = M.config[filetype]
	if not ft_config then
		return nil
	end

	-- Returns the first configured formatter that has an executor (fallback chain)
	for _, name in ipairs(ft_config) do
		local executor = M.executors[name]
		if executor then
			return executor
		end
	end
end

M.format_buffer = function(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filetype = vim.bo[bufnr].filetype

	local executor = resolve_formatter(filetype)
	if executor then
		executor(bufnr, function() end)
	end
end

M.setup = function(opts)
	M.config = opts or {}

	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = "*",
		callback = function(ev)
			local bufnr = ev.buf
			local filetype = vim.bo[bufnr].filetype

			if vim.api.nvim_get_mode().mode ~= "n" then
				return
			end

			if not M.config[filetype] then
				return
			end

			M.format_buffer(bufnr)
		end,
	})
end

return M
