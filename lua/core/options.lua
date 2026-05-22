vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.winborder = "single"
vim.opt.fillchars = { eob = " " }
vim.opt.updatetime = 1000
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.showcmd = true
vim.opt.conceallevel = 0
vim.opt.wrap = false
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.undofile = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.completeopt = "menu,menuone,noselect"
vim.opt.lazyredraw = true
vim.opt.hidden = true
-- see `:h completeopt`
vim.opt.shortmess:append("I")

-- native autocomplete (nvim -v 0.12)
vim.opt.completeopt = "menuone,noselect,popup,fuzzy"
vim.opt.complete:append('o')
vim.o.autocomplete = true;
vim.o.pumheight = 5
vim.o.pumborder = 'rounded'

vim.cmd([[
  hi Normal guibg=NONE ctermbg=NONE
  hi NormalNC guibg=NONE ctermbg=NONE
  hi SignColumn guibg=NONE ctermbg=NONE
  hi LineNr guibg=NONE ctermbg=NONE
  hi EndOfBuffer guibg=NONE ctermbg=NONE
]])


local ok, extui = pcall(require, "vim._extui")
if ok then
	extui.enable({
		enable = true,
	})
end
