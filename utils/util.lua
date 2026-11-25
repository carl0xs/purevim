local M = {}

function M.later(fn)
	vim.defer_fn(fn, 0)
end

-- Root of the current project: nearest `.git` upwards, falling back to cwd
function M.project_root(buf)
	return vim.fs.root(buf or 0, ".git") or vim.fn.getcwd()
end

-- Run `cmd` in a floating `:terminal` that closes when the process exits
function M.float_term(cmd, opts)
	opts = opts or {}
	local width = math.floor(vim.o.columns * (opts.width_ratio or 0.8))
	local height = math.floor(vim.o.lines * (opts.height_ratio or 0.8))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = opts.border,
	})

	vim.fn.jobstart(cmd, {
		term = true,
		cwd = opts.cwd,
		on_exit = function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end,
	})
	vim.cmd("startinsert")
end

return M
