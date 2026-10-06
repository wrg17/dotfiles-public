-- lua/config/keymaps.lua
vim.keymap.set("n", "<leader>|", function()
  vim.fn.system({ "tmux", "split-window", "-h" })
end, { desc = "Tmux split right" })

vim.keymap.set("n", "<leader>_", function()
  vim.fn.system({ "tmux", "split-window", "-v" })
end, { desc = "Tmux split down" })
