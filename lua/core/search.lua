-- lua/core/search.lua
--
-- File finding and grepping using only built-in features:
--   :find      -> fuzzy file finder (`findfunc` + `matchfuzzy`)
--   :grep      -> `grepprg` (ripgrep when available, plain grep otherwise)
--   quickfix   -> results list, refined with :Cfilter / :Cfuzzy
--
-- SOURCE: https://jkrl.me/vim/2025/09/03/nvim-fuzzy-grep.html

-- Load cfilter (shipped with Neovim)
vim.cmd.packadd("cfilter")

local root = require("utils.util").project_root

local M = {}

local ignored_dirs = { [".git"] = true, ["node_modules"] = true, ["target"] = true, [".direnv"] = true }

-- Settings
vim.opt.wildmenu = true
vim.opt.wildmode = { "noselect:lastused", "full" }
vim.opt.wildoptions = { "pum", "fuzzy" }
vim.opt.wildignorecase = true
vim.opt.wildignore:append({ "*/node_modules/*", "*/.git/*" })

-- Neovim already defaults to `rg --vimgrep -uu` when ripgrep is installed and
-- to `grep -n` otherwise; we only tune ripgrep to respect .gitignore.
if vim.fn.executable("rg") == 1 then
	vim.opt.grepprg = "rg --vimgrep --hidden -g '!.git/*'"
end

-- File listing -------------------------------------------------------------

local files_cache = nil

-- Files tracked + untracked (not ignored) when inside git, otherwise a plain
-- directory walk with `vim.fs.dir`.
function M.list_files()
	if files_cache then
		return files_cache
	end

	local dir = root()
	local files
	local res = vim.system(
		{ "git", "ls-files", "--cached", "--others", "--exclude-standard" },
		{ cwd = dir, text = true }
	):wait()

	if res.code == 0 then
		files = vim.split(res.stdout, "\n", { trimempty = true })
	else
		files = {}
		for name, type in
			vim.fs.dir(dir, {
				depth = 20,
				skip = function(d)
					return not ignored_dirs[vim.fs.basename(d)]
				end,
			})
		do
			if type == "file" then
				table.insert(files, name)
			end
		end
	end

	if dir ~= vim.fn.getcwd() then
		for i, f in ipairs(files) do
			files[i] = vim.fn.fnamemodify(dir .. "/" .. f, ":~:.")
		end
	end

	files_cache = files
	return files
end

-- `findfunc` used by :find / :sfind / :vert sf (see `:h findfunc`)
function M.findfunc(cmdarg, _)
	local files = M.list_files()
	if cmdarg == "" then
		return files
	end
	return vim.fn.matchfuzzy(files, cmdarg)
end

_G.PureFindFunc = M.findfunc
vim.o.findfunc = "v:lua.PureFindFunc"

-- Invalidate the cache when the file list may have changed
vim.api.nvim_create_autocmd({ "DirChanged", "BufNewFile", "BufWritePost", "FocusGained" }, {
	group = vim.api.nvim_create_augroup("PureFindCache", { clear = true }),
	callback = function()
		files_cache = nil
	end,
})

-- Cmdline autocompletion as you type (nvim >= 0.12, `:h cmdline-autocompletion`)
if vim.fn.exists("*wildtrigger") == 1 then
	vim.api.nvim_create_autocmd("CmdlineChanged", {
		group = vim.api.nvim_create_augroup("PureCmdlineComplete", { clear = true }),
		pattern = ":",
		callback = function()
			local line = vim.fn.getcmdline()
			if line:match("^%s*fin?d?%s") or line:match("^%s*vert%a*%s+sf%a*%s") or line:match("^%s*b%a*%s") then
				vim.fn.wildtrigger()
			end
		end,
	})
end

-- Quickfix helpers -----------------------------------------------------------

function M.fuzzy_filter_qf(...)
	local query = table.concat({ ... }, " ")
	vim.fn.setqflist(vim.fn.matchfuzzy(vim.fn.getqflist(), query, { key = "text" }))
end

function M.fuzzy_filter_grep(query, path)
	path = path or "."
	vim.cmd("silent grep! " .. vim.fn.shellescape(query) .. " " .. path)
	local sort_query = query:gsub("%.%*", ""):gsub("\\%(.)", "%1")
	M.fuzzy_filter_qf(sort_query)
	vim.cmd("cfirst")
	vim.cmd("copen")
end

-- Send every file matching a (fuzzy) query to the quickfix list
function M.files_to_quickfix(...)
	local query = table.concat({ ... }, " ")
	local qf = {}
	for _, f in ipairs(M.findfunc(query)) do
		table.insert(qf, { filename = f, lnum = 1, text = f })
	end
	vim.fn.setqflist(qf)
	vim.cmd("copen")
end

-- Commands
vim.api.nvim_create_user_command("Findqf", function(opts)
	M.files_to_quickfix(unpack(opts.fargs))
end, { nargs = "+", complete = "file_in_path" })

vim.api.nvim_create_user_command("Cfuzzy", function(opts)
	M.fuzzy_filter_qf(unpack(opts.fargs))
end, { nargs = 1 })

vim.api.nvim_create_user_command("Zgrep", function(opts)
	M.fuzzy_filter_grep(unpack(opts.fargs))
end, { nargs = "+", complete = "file_in_path" })

-- Grep the whole project, results in the quickfix list
vim.api.nvim_create_user_command("PureGrep", function(opts)
	local query = opts.args ~= "" and opts.args or vim.fn.input("Grep: ")
	if query == "" then
		return
	end
	vim.cmd("silent grep! " .. vim.fn.shellescape(query) .. " " .. vim.fn.fnameescape(root()))
end, { nargs = "?" })

-- Preview the quickfix entry under the cursor with `p`, keeping focus
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("PureQfPreview", { clear = true }),
	pattern = "qf",
	callback = function(ev)
		vim.keymap.set("n", "p", "<CR><C-w>p", { buffer = ev.buf, desc = "Preview entry" })
	end,
})

return M
