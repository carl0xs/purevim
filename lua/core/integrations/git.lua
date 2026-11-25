-- Git integration built on top of the `git` CLI and native APIs:
--   * signs      -> diff of the buffer against HEAD with `vim.text.diff`,
--                   rendered as extmark signs (updates while typing)
--   * hunks      -> ]c / [c navigation
--   * blame      -> inline virtual text, one async `git blame` per buffer
--   * branch     -> read straight from .git/HEAD (no process spawned)
--   * status     -> changed files in the quickfix list
--   * diff       -> scratch buffers with `git diff`
--   * annotate   -> scroll-bound side window

local M = {}

local api = vim.api
local ns_signs = api.nvim_create_namespace("pure_git_signs")
local ns_blame = api.nvim_create_namespace("pure_blame_ns")

local diff = vim.text and vim.text.diff or vim.diff

M.blame_enabled = false

-- Per buffer state: { root, base (HEAD lines), hunks, blame }
local state = {}

local signs = {
	add = "+",
	change = "~",
	delete = "-",
}

local function git_root(buf)
	return vim.fs.root(buf or 0, ".git")
end

local function is_file_buffer(buf)
	return api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" and api.nvim_buf_get_name(buf) ~= ""
end

local function setup_signs(opts)
	signs = vim.tbl_extend("force", signs, (opts or {}).staged or {})

	api.nvim_set_hl(0, "GitSignsAdd", { default = true, fg = "#98c379" })
	api.nvim_set_hl(0, "GitSignsChange", { default = true, fg = "#61afef" })
	api.nvim_set_hl(0, "GitSignsDelete", { default = true, fg = "#993939" })
end

-- Signs ----------------------------------------------------------------------

local function render_signs(buf)
	local s = state[buf]
	if not s or not s.base or not api.nvim_buf_is_valid(buf) then
		return
	end

	local current = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
	local indices = diff(s.base, current, { result_type = "indices", algorithm = "histogram" }) or {}

	api.nvim_buf_clear_namespace(buf, ns_signs, 0, -1)
	s.hunks = {}

	local line_count = api.nvim_buf_line_count(buf)
	local function place(lnum, text, hl)
		lnum = math.max(1, math.min(lnum, line_count))
		api.nvim_buf_set_extmark(buf, ns_signs, lnum - 1, 0, { sign_text = text, sign_hl_group = hl, priority = 6 })
	end

	for _, h in ipairs(indices) do
		local _, old_count, new_start, new_count = unpack(h)
		if new_count == 0 then
			place(new_start == 0 and 1 or new_start, signs.delete, "GitSignsDelete")
			table.insert(s.hunks, math.max(new_start, 1))
		else
			local text, hl = signs.change, "GitSignsChange"
			if old_count == 0 then
				text, hl = signs.add, "GitSignsAdd"
			end
			for l = new_start, new_start + new_count - 1 do
				place(l, text, hl)
			end
			table.insert(s.hunks, new_start)
		end
	end
end

-- Fetch the HEAD version of the file asynchronously, then render
local function refresh(buf)
	buf = buf or api.nvim_get_current_buf()
	if not is_file_buffer(buf) then
		return
	end

	local root = git_root(buf)
	if not root then
		state[buf] = nil
		return
	end

	local path = vim.fs.normalize(api.nvim_buf_get_name(buf))
	local rel = path:sub(#root + 2)

	vim.system({ "git", "show", "HEAD:" .. rel }, { cwd = root, text = true }, function(res)
		vim.schedule(function()
			if not api.nvim_buf_is_valid(buf) then
				return
			end
			state[buf] = state[buf] or {}
			state[buf].root = root
			state[buf].blame = nil
			if res.code ~= 0 then
				-- untracked / new file: no base to compare against
				state[buf].base = nil
				state[buf].hunks = {}
				api.nvim_buf_clear_namespace(buf, ns_signs, 0, -1)
				return
			end
			state[buf].base = res.stdout
			render_signs(buf)
		end)
	end)
end

M.refresh = refresh

-- Hunk navigation --------------------------------------------------------------

local function jump(forward)
	local hunks = (state[api.nvim_get_current_buf()] or {}).hunks or {}
	if #hunks == 0 then
		return
	end

	local cur = api.nvim_win_get_cursor(0)[1]
	local target
	if forward then
		for _, l in ipairs(hunks) do
			if l > cur then
				target = l
				break
			end
		end
		target = target or hunks[1]
	else
		for i = #hunks, 1, -1 do
			if hunks[i] < cur then
				target = hunks[i]
				break
			end
		end
		target = target or hunks[#hunks]
	end

	api.nvim_win_set_cursor(0, { target, 0 })
	vim.cmd("normal! zz")
end

function M.next_hunk()
	jump(true)
end

function M.prev_hunk()
	jump(false)
end

-- Branch ------------------------------------------------------------------------

-- Reads .git/HEAD directly (supports worktrees/submodules where .git is a file)
function M.branch(buf)
	local root = git_root(buf)
	if not root then
		return nil
	end

	local git = root .. "/.git"
	if vim.fn.isdirectory(git) == 0 then
		local f = io.open(git)
		local content = f and f:read("*l") or ""
		if f then
			f:close()
		end
		local dir = content:match("^gitdir:%s*(.+)$")
		if not dir then
			return nil
		end
		git = dir:sub(1, 1) == "/" and dir or (root .. "/" .. dir)
	end

	local f = io.open(git .. "/HEAD")
	if not f then
		return nil
	end
	local head = f:read("*l") or ""
	f:close()

	return head:match("^ref: refs/heads/(.+)$") or head:sub(1, 7)
end

-- Blame -------------------------------------------------------------------------

local function parse_blame(lines)
	local result, commits = {}, {}
	local sha, lnum
	for _, line in ipairs(lines) do
		local h, _, final = line:match("^(%x+) (%d+) (%d+)")
		if h and #h == 40 then
			sha, lnum = h, tonumber(final)
			commits[sha] = commits[sha] or {}
		elseif line:sub(1, 1) == "\t" then
			result[lnum] = commits[sha]
		elseif sha then
			local key, value = line:match("^(%S+) (.*)$")
			if key then
				commits[sha][key] = value
			end
		end
	end
	return result
end

local function blame_text(info)
	if not info or info.author == "Not Committed Yet" or info.author == "External file (--contents)" then
		return "Uncommitted changes"
	end
	local date = info["author-time"] and os.date("%Y-%m-%d %H:%M:%S", tonumber(info["author-time"])) or ""
	return string.format("%s | %s | %s", info.summary or "", info.author or "", date)
end

local function show_blame()
	local buf = api.nvim_get_current_buf()
	api.nvim_buf_clear_namespace(buf, ns_blame, 0, -1)
	if not M.blame_enabled or not is_file_buffer(buf) then
		return
	end

	local s = state[buf]
	if not s or not s.root then
		return
	end

	local row = api.nvim_win_get_cursor(0)[1]
	if s.blame then
		api.nvim_buf_set_extmark(buf, ns_blame, row - 1, 0, {
			virt_text = { { blame_text(s.blame[row]), "Comment" } },
			virt_text_pos = "eol",
		})
		return
	end

	if s.blame_pending then
		return
	end
	s.blame_pending = true

	-- Blame the buffer contents (not the file on disk) so line numbers match
	local content = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
	vim.system(
		{ "git", "blame", "--porcelain", "--contents", "-", "--", api.nvim_buf_get_name(buf) },
		{ cwd = s.root, text = true, stdin = content },
		function(res)
			vim.schedule(function()
				s.blame_pending = false
				if res.code ~= 0 then
					return
				end
				s.blame = parse_blame(vim.split(res.stdout, "\n"))
				if api.nvim_get_current_buf() == buf then
					show_blame()
				end
			end)
		end
	)
end

function M.toggle_blame()
	M.blame_enabled = not M.blame_enabled
	show_blame()
	vim.notify(M.blame_enabled and "Blame enabled" or "Blame disabled")
end

-- Status / diff / annotate ------------------------------------------------------

-- Changed files in the quickfix list (`:cnext`, `:Cfilter`, `p` to preview)
function M.status()
	local root = git_root()
	if not root then
		vim.notify("Not a git repository", vim.log.levels.WARN)
		return
	end

	local res = vim.system({ "git", "status", "--porcelain" }, { cwd = root, text = true }):wait()
	local items = {}
	for _, line in ipairs(vim.split(res.stdout or "", "\n", { trimempty = true })) do
		local flags, file = line:sub(1, 2), line:sub(4)
		file = file:match("-> (.+)$") or file
		table.insert(items, { filename = root .. "/" .. file, lnum = 1, text = "[" .. flags .. "]" })
	end

	vim.fn.setqflist({}, " ", { title = "Git status", items = items })
	vim.cmd("copen")
end

local function scratch_vsplit(lines, filetype, cmd)
	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = filetype or ""
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	vim.cmd(cmd or "vsplit")
	api.nvim_win_set_buf(0, buf)
	return buf
end

-- `git diff` of the current file, or the whole repo when `all` is true
function M.diff(all)
	local cmd = { "git", "diff" }
	if not all then
		local file = vim.fn.expand("%:p")
		if file == "" then
			vim.notify("No file name for current buffer", vim.log.levels.WARN)
			return
		end
		vim.list_extend(cmd, { "--", file })
	end

	local res = vim.system(cmd, { cwd = git_root() or vim.fn.getcwd(), text = true }):wait()
	if res.code ~= 0 then
		vim.notify("git diff failed or repo not found", vim.log.levels.WARN)
		return
	end
	scratch_vsplit(vim.split(res.stdout, "\n", { trimempty = true }), "diff")
end

function M.annotate()
	local file = vim.fn.expand("%:p")
	if file == "" then
		vim.notify("No file name for current buffer", vim.log.levels.WARN)
		return
	end

	local res = vim.system({ "git", "annotate", "--", file }, { cwd = git_root(), text = true }):wait()
	if res.code ~= 0 then
		vim.notify("git annotate failed or repo not found", vim.log.levels.WARN)
		return
	end

	local lines = {}
	for _, line in ipairs(vim.split(res.stdout, "\n", { trimempty = true })) do
		table.insert(lines, line:match("^(%x+%s+%([^)]*%d+%))") or line)
	end

	local cursor_line = vim.fn.line(".")
	local original_win = api.nvim_get_current_win()

	local buf = scratch_vsplit(lines, "gitannotate", "topleft vsplit")
	api.nvim_buf_call(buf, function()
		vim.cmd([[
			syntax match GitAnnotateHash /^\x\+/
			syntax match GitAnnotateAuthor /(\zs[^)]*\d\{4\}-\d\{2\}-\d\{2\}/
			syntax match GitAnnotateLineNr /\d\+)$/
			highlight default link GitAnnotateHash Identifier
			highlight default link GitAnnotateAuthor String
			highlight default link GitAnnotateLineNr LineNr
		]])
	end)

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	local win = api.nvim_get_current_win()
	api.nvim_win_set_width(win, width + 2)
	api.nvim_win_set_cursor(win, { math.min(cursor_line, #lines), 0 })

	vim.wo[win].scrollbind = true
	vim.wo[original_win].scrollbind = true
	vim.wo[original_win].foldenable = false
	vim.cmd("syncbind")
	api.nvim_set_current_win(original_win)
end

-- Setup -------------------------------------------------------------------------

--- @alias signs { staged: { add: string, change: string, delete: string } }
--- @param opts? { signs: signs }
function M.setup(opts)
	opts = opts or {}
	setup_signs(opts.signs)

	local group = api.nvim_create_augroup("PureGit", { clear = true })

	api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "FocusGained" }, {
		group = group,
		callback = function(ev)
			refresh(ev.buf)
		end,
	})

	-- Re-diff in-process while editing (cheap, no git call)
	local timer = assert(vim.uv.new_timer())
	api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(ev)
			if not state[ev.buf] then
				return
			end
			timer:stop()
			timer:start(150, 0, vim.schedule_wrap(function()
				render_signs(ev.buf)
			end))
		end,
	})

	api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(ev)
			state[ev.buf] = nil
		end,
	})

	api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		callback = show_blame,
	})

	api.nvim_create_user_command("PureGitStatus", M.status, {})
	api.nvim_create_user_command("PureGitDiff", function(o)
		M.diff(o.bang)
	end, { bang = true, desc = "git diff of current file (! for whole repo)" })
	api.nvim_create_user_command("PureGitAnnotate", M.annotate, {})

	-- Modules are loaded deferred, so buffers opened at startup need a refresh
	for _, buf in ipairs(api.nvim_list_bufs()) do
		if api.nvim_buf_is_loaded(buf) then
			refresh(buf)
		end
	end
end

return M
