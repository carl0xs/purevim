-- Native tree-sitter: highlighting, folding and indentation.
-- Neovim ships parsers for c, lua, vim, vimdoc, query and markdown; other
-- languages need their parser in a `parser/` directory on the runtimepath.

-- Folding setup
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevelstart = 99

-- Start Tree-sitter parsing for every file type that has a parser
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("PureTreesitter", { clear = true }),
	callback = function(ev)
		pcall(vim.treesitter.start, ev.buf)
	end,
})

-- Buffers opened before this module was loaded (it is loaded deferred)
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
	if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= "" then
		pcall(vim.treesitter.start, buf)
	end
end

function PureCheckTreesitter()
	local ok, parser = pcall(vim.treesitter.get_parser, 0)
	if ok and parser then
		print("Tree-sitter is running on parser: " .. parser:lang())
	else
		print("No Tree-sitter parser attached to this buffer")
	end
end

vim.api.nvim_create_user_command("PureCheckTreesitter", PureCheckTreesitter, {})
