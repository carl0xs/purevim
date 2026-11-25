local git = require("core.integrations.git")

-- Cache git branch per buffer (git.branch only reads .git/HEAD, but the
-- statusline is redrawn very often)
local git_cache = {}

local function git_branch()
  local buf = vim.api.nvim_get_current_buf()
  if git_cache[buf] == nil then
    local branch = git.branch(buf)
    if branch and #branch > 25 then
      branch = branch:sub(1, 25) .. "…"
    end
    git_cache[buf] = branch and (" " .. branch) or false
  end
  return git_cache[buf] or nil
end

local function short_filename()
  local fullpath = vim.fn.expand("%:p")
  if fullpath == "" then return "" end

  local filename = vim.fn.fnamemodify(fullpath, ":t")
  local dirname  = vim.fn.fnamemodify(fullpath, ":h:t")

  return dirname .. "/" .. filename
end

-- Clear cache when buffer is entered or git branch might change
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained" }, {
  callback = function()
    git_cache = {}
  end,
})

local function statusline()
  local parts = { " ", short_filename() , "%y", "%m" }
  local right = {}
  local branch = git_branch()
  if branch then
    table.insert(right, branch)
  end
  table.insert(right, "Ln %l, Col %c")
  table.insert(right, "[%p%%] ")
  return table.concat(parts, " ") .. " %= " .. table.concat(right, " | ")
end

vim.opt.laststatus = 3
vim.opt.statusline = "%!v:lua.statusline()"
_G.statusline = statusline
