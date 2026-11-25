-- Optional: lazygit in a floating terminal (only if lazygit is installed).
-- Everything else git related works with plain `git`, see core.integrations.git
local util = require("utils.util")

vim.api.nvim_create_user_command("PureLazyGit", function()
	if vim.fn.executable("lazygit") == 0 then
		vim.notify("lazygit not found, falling back to :PureGitStatus", vim.log.levels.WARN)
		require("core.integrations.git").status()
		return
	end
	util.float_term({ "lazygit" }, { cwd = util.project_root() })
end, {})
