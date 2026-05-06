vim.opt.guifont = "FiraCode Nerd Font Mono:h12"

-- Better UI spacing
vim.opt.linespace = 2

-- Truecolor (defensive)
vim.opt.termguicolors = true

vim.opt.relativenumber = true -- shows distance to other lines: now `7j` jumps where you eyeballed
vim.opt.scrolloff = 8 -- cursor never glued to the screen edge
vim.opt.sidescrolloff = 8 -- same, horizontally
vim.opt.confirm = true -- prompt to save instead of erroring on :q
vim.opt.undofile = true -- persistent undo across nvim restarts
vim.opt.smartcase = true -- /Foo is case-sensitive, /foo isn't
vim.opt.ignorecase = true -- (required for smartcase to work)
