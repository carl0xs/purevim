-- File explorer that edits the filesystem like a buffer (in the spirit of
-- stevearc/oil.nvim), built only on native APIs: `vim.fs`, `vim.uv`,
-- extmarks and `BufReadCmd`/`BufWriteCmd` on `pure://` buffers.
--
-- Each line is `/<id> <name>` where `/<id> ` is concealed. The id tracks the
-- original entry, so on `:w` the edits become filesystem actions:
--   * changed name        -> rename / move (`sub/dir/name` and trailing `/` work)
--   * deleted line        -> delete
--   * new line (no id)    -> create (`name/` creates a directory)
--   * duplicated line     -> copy
--   * `dd` here + `p` in another explorer buffer -> move between directories
--
-- Keys: <CR> open, - parent, _ cwd, g. toggle hidden, <C-l> refresh, q close

local M = {}

local api, uv = vim.api, vim.uv
local SCHEME = "pure://"
local ns = api.nvim_create_namespace("pure_explorer")

M.config = {
	columns = { "permissions", "size", "mtime" },
	show_hidden = false,
	-- Skip the confirmation when there are no deletes and at most one move/copy
	skip_confirm_for_simple_edits = true,
}

-- Entry ids are global so lines can be moved between explorer buffers
local id_by_path, path_by_id, next_id = {}, {}, 1

-- Per buffer: { dir = absolute path, ids = { [id] = true } rendered ids }
local state = {}

local function join(dir, name)
	return dir == "/" and "/" .. name or dir .. "/" .. name
end

local function normalize_dir(dir)
	dir = vim.fs.normalize(vim.fs.abspath(dir))
	return dir == "" and "/" or dir
end

local function id_for(path)
	local id = id_by_path[path]
	if not id then
		id, next_id = next_id, next_id + 1
		id_by_path[path], path_by_id[id] = id, path
	end
	return id
end

local function display(path)
	return vim.fn.fnamemodify(path, ":~:.")
end

-- Columns -----------------------------------------------------------------------

local function permissions(st)
	local kind = ({ directory = "d", link = "l" })[st.type] or "-"
	local bits = {}
	for i = 8, 0, -1 do
		local on = bit.band(st.mode, bit.lshift(1, i)) ~= 0
		bits[#bits + 1] = on and ("rwx"):sub(3 - i % 3, 3 - i % 3) or "-"
	end
	return kind .. table.concat(bits)
end

local function size(st)
	if st.type == "directory" then
		return "-"
	end
	local s, units = st.size, { "B", "K", "M", "G", "T" }
	local u = 1
	while s >= 1024 and u < #units do
		s, u = s / 1024, u + 1
	end
	return u == 1 and (s .. "B") or string.format("%.1f%s", s, units[u])
end

local function mtime(st)
	local fmt = os.time() - st.mtime.sec > 180 * 86400 and "%b %d  %Y" or "%b %d %H:%M"
	return os.date(fmt, st.mtime.sec)
end

local column_fn = {
	permissions = { permissions, "Comment" },
	size = { size, "Number" },
	mtime = { mtime, "Comment" },
}

-- Render ------------------------------------------------------------------------

local function list_dir(dir)
	local entries = {}
	for name in vim.fs.dir(dir) do
		if M.config.show_hidden or name:sub(1, 1) ~= "." then
			local path = join(dir, name)
			local lst = uv.fs_lstat(path)
			local st = uv.fs_stat(path) or lst
			if st then
				table.insert(entries, { name = name, path = path, is_dir = st.type == "directory", stat = lst })
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.is_dir ~= b.is_dir then
			return a.is_dir
		end
		return a.name:lower() < b.name:lower()
	end)
	return entries
end

local function render(buf)
	local s = state[buf]
	local entries = list_dir(s.dir)

	s.ids = {}
	local lines, cols, widths = {}, {}, {}
	for i, e in ipairs(entries) do
		local id = id_for(e.path)
		s.ids[id] = true
		lines[i] = string.format("/%d %s%s", id, e.name, e.is_dir and "/" or "")

		cols[i] = {}
		for c, name in ipairs(M.config.columns) do
			local text = column_fn[name] and column_fn[name][1](e.stat) or ""
			cols[i][c] = text
			widths[c] = math.max(widths[c] or 0, vim.fn.strdisplaywidth(text))
		end
	end

	-- Replace the content without leaving it in the undo history
	local undolevels = vim.bo[buf].undolevels
	vim.bo[buf].undolevels = -1
	vim.bo[buf].modifiable = true
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].undolevels = undolevels
	vim.bo[buf].modified = false

	api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for i in ipairs(lines) do
		local chunks = {}
		for c, name in ipairs(M.config.columns) do
			local text = cols[i][c]
			local pad = string.rep(" ", widths[c] - vim.fn.strdisplaywidth(text))
			-- numbers align right, everything else left
			text = name == "size" and pad .. text or text .. pad
			table.insert(chunks, { text .. "  ", column_fn[name] and column_fn[name][2] or "Comment" })
		end
		if #chunks > 0 then
			api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_text = chunks,
				virt_text_pos = "inline",
				right_gravity = false,
			})
		end
	end
end

local function refresh_all()
	for buf in pairs(state) do
		if api.nvim_buf_is_loaded(buf) then
			render(buf)
		else
			state[buf] = nil
		end
	end
end

-- Line parsing ---------------------------------------------------------------------

local function parse_line(line)
	local id, name = line:match("^/(%d+) (.*)$")
	return tonumber(id), vim.trim(name or line)
end

local function entry_under_cursor()
	local s = state[api.nvim_get_current_buf()]
	local _, name = parse_line(api.nvim_get_current_line())
	if not s or name == "" then
		return nil
	end
	return join(s.dir, (name:gsub("/+$", "")))
end

-- Keep the cursor out of the concealed `/<id> ` prefix
local function clamp_cursor()
	local row, col = unpack(api.nvim_win_get_cursor(0))
	local prefix = api.nvim_get_current_line():match("^/%d+ ")
	if prefix and col < #prefix then
		api.nvim_win_set_cursor(0, { row, #prefix })
	end
end

-- Open ------------------------------------------------------------------------------

function M.open(dir, focus)
	dir = normalize_dir(dir or vim.fn.getcwd())
	if vim.fn.isdirectory(dir) == 0 then
		vim.notify("[explorer] not a directory: " .. dir, vim.log.levels.ERROR)
		return
	end

	local buf = vim.fn.bufadd(SCHEME .. (dir == "/" and "/" or dir .. "/"))
	vim.cmd.buffer(buf)

	if focus then
		for i, line in ipairs(api.nvim_buf_get_lines(buf, 0, -1, false)) do
			local _, name = parse_line(line)
			if name:gsub("/$", "") == focus then
				api.nvim_win_set_cursor(0, { i, 0 })
				break
			end
		end
	end
	clamp_cursor()
end

-- Open the directory of the current file, with the cursor on it
function M.open_parent()
	local s = state[api.nvim_get_current_buf()]
	if s then
		if s.dir ~= "/" then
			M.open(vim.fs.dirname(s.dir), vim.fs.basename(s.dir))
		end
		return
	end

	local file = api.nvim_buf_get_name(0)
	if file == "" or vim.bo.buftype ~= "" then
		M.open(vim.fn.getcwd())
	else
		M.open(vim.fs.dirname(file), vim.fs.basename(file))
	end
end

local function select_entry()
	local path = entry_under_cursor()
	if not path then
		return
	end
	if vim.fn.isdirectory(path) == 1 then
		M.open(path)
	elseif vim.bo.modified and not uv.fs_stat(path) then
		vim.notify("[explorer] save (:w) to create " .. display(path), vim.log.levels.WARN)
	else
		vim.cmd.edit(vim.fn.fnameescape(path))
	end
end

local function close()
	local alt = vim.fn.bufnr("#")
	if alt > 0 and alt ~= api.nvim_get_current_buf() and vim.fn.buflisted(alt) == 1 then
		vim.cmd.buffer(alt)
	else
		vim.cmd.enew()
	end
end

-- Filesystem actions ------------------------------------------------------------------

local function copy_path(src, dst)
	local st = assert(uv.fs_lstat(src))
	if st.type == "directory" then
		vim.fn.mkdir(dst, "p")
		for name in vim.fs.dir(src) do
			copy_path(join(src, name), join(dst, name))
		end
	elseif st.type == "link" then
		assert(uv.fs_symlink(assert(uv.fs_readlink(src)), dst))
	else
		assert(uv.fs_copyfile(src, dst))
	end
end

local function move_path(src, dst)
	local ok, err = uv.fs_rename(src, dst)
	if not ok then
		if not tostring(err):match("EXDEV") then
			error(err)
		end
		copy_path(src, dst)
		vim.fs.rm(src, { recursive = true, force = true })
	end
end

-- Keep loaded buffers pointing at moved files
local function rename_buffers(src, dst)
	for _, b in ipairs(api.nvim_list_bufs()) do
		local name = api.nvim_buf_get_name(b)
		if name == src or vim.startswith(name, src .. "/") then
			api.nvim_buf_set_name(b, dst .. name:sub(#src + 1))
			if api.nvim_buf_is_loaded(b) and not vim.bo[b].modified then
				api.nvim_buf_call(b, function()
					vim.cmd("silent! edit!")
				end)
			end
		end
	end
end

-- Turn the edited explorer buffers into a list of actions
local function compute_actions(bufs)
	local dests, creates, seen = {}, {}, {}

	for _, buf in ipairs(bufs) do
		local dir = state[buf].dir
		for _, line in ipairs(api.nvim_buf_get_lines(buf, 0, -1, false)) do
			local id, name = parse_line(line)
			if name ~= "" then
				local is_dir = name:sub(-1) == "/"
				name = name:gsub("/+$", "")
				for part in vim.gsplit(name, "/", { plain = true }) do
					if part == "" or part == "." or part == ".." then
						error("invalid name: " .. line)
					end
				end

				local path = join(dir, name)
				if seen[path] then
					error("duplicate entry: " .. display(path))
				end
				seen[path] = true

				if id and path_by_id[id] then
					dests[id] = dests[id] or {}
					table.insert(dests[id], path)
				else
					table.insert(creates, { type = "create", dst = path, is_dir = is_dir })
				end
			end
		end
	end

	local actions, handled = {}, {}
	for _, buf in ipairs(bufs) do
		for id in pairs(state[buf].ids) do
			local src, targets = path_by_id[id], dests[id] or {}
			local moved = vim.tbl_contains(targets, src)
			for _, dst in ipairs(targets) do
				if dst ~= src then
					table.insert(actions, { type = moved and "copy" or "move", src = src, dst = dst })
					moved = true
				end
			end
			if #targets == 0 then
				table.insert(actions, { type = "delete", src = src })
			end
			handled[id] = true
		end
	end

	-- Entries pasted from an explorer buffer that was not edited are copies
	for id, targets in pairs(dests) do
		if not handled[id] then
			for _, dst in ipairs(targets) do
				if dst ~= path_by_id[id] then
					table.insert(actions, { type = "copy", src = path_by_id[id], dst = dst })
				end
			end
		end
	end

	vim.list_extend(actions, creates)
	return actions
end

local function validate(actions)
	local freed = {}
	for _, a in ipairs(actions) do
		if a.type == "move" or a.type == "delete" then
			freed[a.src] = true
		end
	end
	for _, a in ipairs(actions) do
		if a.dst and uv.fs_lstat(a.dst) and not freed[a.dst] then
			error("already exists: " .. display(a.dst))
		end
		if a.src and not uv.fs_lstat(a.src) then
			error("no longer exists: " .. display(a.src))
		end
	end
end

local function is_simple(actions)
	local transfers = 0
	for _, a in ipairs(actions) do
		if a.type == "delete" then
			return false
		elseif a.type == "move" or a.type == "copy" then
			transfers = transfers + 1
		end
	end
	return transfers <= 1
end

local function confirm(actions)
	if M.config.skip_confirm_for_simple_edits and is_simple(actions) then
		return true
	end
	local lines = {}
	for _, a in ipairs(actions) do
		local label = a.type:upper()
		if a.type == "delete" then
			table.insert(lines, string.format("  %-6s %s", label, display(a.src)))
		elseif a.type == "create" then
			table.insert(lines, string.format("  %-6s %s%s", label, display(a.dst), a.is_dir and "/" or ""))
		else
			table.insert(lines, string.format("  %-6s %s -> %s", label, display(a.src), display(a.dst)))
		end
	end
	return vim.fn.confirm("Apply changes?\n\n" .. table.concat(lines, "\n"), "&Yes\n&No", 2) == 1
end

local function apply(actions)
	-- 1. moves go through a temporary name first, so swaps (a <-> b) work
	local current = {}
	for _, a in ipairs(actions) do
		if a.type == "move" then
			a.tmp = string.format("%s.pure-explorer-%d-%d", a.src, uv.os_getpid(), uv.hrtime())
			move_path(a.src, a.tmp)
			current[a.src] = a.tmp
		end
	end
	-- 2. deletes
	for _, a in ipairs(actions) do
		if a.type == "delete" then
			assert(vim.fs.rm(a.src, { recursive = true, force = true }) ~= false)
		end
	end
	-- 3. copies (from wherever the source is now)
	for _, a in ipairs(actions) do
		if a.type == "copy" then
			vim.fn.mkdir(vim.fs.dirname(a.dst), "p")
			copy_path(current[a.src] or a.src, a.dst)
		end
	end
	-- 4. moves to their final destination
	for _, a in ipairs(actions) do
		if a.type == "move" then
			vim.fn.mkdir(vim.fs.dirname(a.dst), "p")
			move_path(a.tmp, a.dst)
			rename_buffers(a.src, a.dst)
		end
	end
	-- 5. creates
	for _, a in ipairs(actions) do
		if a.type == "create" then
			if a.is_dir then
				vim.fn.mkdir(a.dst, "p")
			else
				vim.fn.mkdir(vim.fs.dirname(a.dst), "p")
				uv.fs_close(assert(uv.fs_open(a.dst, "wx", 420)))
			end
		end
	end
end

-- Save every modified explorer buffer at once, like oil does
function M.save()
	local bufs = {}
	for buf in pairs(state) do
		if api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
			table.insert(bufs, buf)
		end
	end

	local ok, actions = pcall(compute_actions, bufs)
	if ok then
		ok, actions = pcall(function()
			validate(actions)
			return actions
		end)
	end
	if not ok then
		vim.notify("[explorer] " .. tostring(actions):gsub("^.-:%d+: ", ""), vim.log.levels.ERROR)
		return
	end

	if #actions == 0 then
		refresh_all()
		return
	end
	if not confirm(actions) then
		return
	end

	local applied, err = pcall(apply, actions)
	refresh_all()
	if not applied then
		vim.notify("[explorer] " .. tostring(err), vim.log.levels.ERROR)
	end
end

-- Buffer setup ----------------------------------------------------------------------

local function setup_buffer(buf)
	local name = api.nvim_buf_get_name(buf)
	state[buf] = state[buf] or { dir = normalize_dir(name:sub(#SCHEME + 1)), ids = {} }

	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "pureexplorer"

	api.nvim_buf_call(buf, function()
		vim.cmd([[
			syntax clear
			syntax match PureExplorerId /^\/\d\+ / conceal
			syntax match PureExplorerDir /\%(^\/\d\+ \)\@<=.*\/$\|^[^/].*\/$/
			highlight default link PureExplorerDir Directory
		]])
	end)

	local function map(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, desc = desc })
	end
	map("<CR>", select_entry, "Open entry")
	map("-", M.open_parent, "Parent directory")
	map("_", function()
		M.open(vim.fn.getcwd())
	end, "Open cwd")
	map("g.", function()
		if vim.bo[buf].modified then
			vim.notify("[explorer] save or undo your changes first", vim.log.levels.WARN)
			return
		end
		M.config.show_hidden = not M.config.show_hidden
		refresh_all()
	end, "Toggle hidden files")
	map("<C-l>", function()
		if vim.bo[buf].modified then
			vim.notify("[explorer] buffer has unsaved changes", vim.log.levels.WARN)
		else
			render(buf)
		end
	end, "Refresh")
	map("q", close, "Close explorer")

	render(buf)
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	local group = api.nvim_create_augroup("PureExplorer", { clear = true })

	api.nvim_create_autocmd("BufReadCmd", {
		group = group,
		pattern = SCHEME .. "*",
		callback = function(ev)
			setup_buffer(ev.buf)
		end,
	})

	api.nvim_create_autocmd("BufWriteCmd", {
		group = group,
		pattern = SCHEME .. "*",
		callback = M.save,
	})

	api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		pattern = SCHEME .. "*",
		callback = function()
			vim.opt_local.conceallevel = 3
			vim.opt_local.concealcursor = "nvic"
			vim.opt_local.wrap = false
		end,
	})

	api.nvim_create_autocmd("BufWipeout", {
		group = group,
		pattern = SCHEME .. "*",
		callback = function(ev)
			state[ev.buf] = nil
		end,
	})

	api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		pattern = SCHEME .. "*",
		callback = clamp_cursor,
	})

	-- Replace directory buffers (`nvim .`, `:e src/`), netrw is disabled in init.lua
	local function hijack(buf)
		local name = api.nvim_buf_get_name(buf)
		if name == "" or vim.bo[buf].buftype ~= "" or vim.fn.isdirectory(name) == 0 then
			return
		end
		vim.schedule(function()
			if api.nvim_get_current_buf() == buf then
				M.open(name)
			end
			if api.nvim_buf_is_valid(buf) then
				api.nvim_buf_delete(buf, { force = true })
			end
		end)
	end

	api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(ev)
			hijack(ev.buf)
		end,
	})
	hijack(api.nvim_get_current_buf())

	api.nvim_create_user_command("PureExplore", function(o)
		M.open(o.args ~= "" and o.args or nil)
	end, { nargs = "?", complete = "dir" })

	if vim.fn.exists(":Explore") ~= 2 then
		api.nvim_create_user_command("Explore", function(o)
			M.open(o.args ~= "" and o.args or vim.fn.expand("%:p:h"))
		end, { nargs = "?", complete = "dir" })
	end

	vim.keymap.set("n", "-", M.open_parent, { desc = "Open parent directory" })
end

return M
