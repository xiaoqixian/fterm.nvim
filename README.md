<h1 align='center'>fterm.nvim</h1>

A fork of the original [FTerm.nvim](https://github.com/numToStr/FTerm.nvim),
but supports multiple terminal tabs.

You can create some terminal keymaps to create and jump between tabs.

Default keymaps:
- create new tab: `<leader>tt`
- next tab: `<tab>`
- prev tab: `<S-tab>`

All keymaps are created buffer-locally, so you don't have worry about 
other keymaps with same keys jeopardized.

All keymaps are created in terminal mode, so you have to enter the terminal 
mode to invoke these keymaps. 
You can create a keymap to enter terminal mode quickly, e.g.,
```lua
vim.keymap.set("t", "jj", "<C-\\><C-n>", {noremap = true, desc = "enter terminal mode"})
```
