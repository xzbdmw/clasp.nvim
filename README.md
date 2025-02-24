# Clasp.nvim ⎇
**Cl**ever **A**daptive **S**urround **P**airs

A pair wrapping plugin with:
* **Single Keymap** (`<c-l>` to cycling forward/backward, `u` to undo previous cycle)
* **Incremental node traversal** (TS-powered)
* **Multi-cursor** aware, works with [multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim)

## Show case with multicursor.nvim




https://github.com/user-attachments/assets/8f09f5ff-00ef-45dd-a76e-a40c8ecd09c1








## Installation

With **lazy.nvim**:

```lua
return {
    "xzbdmw/clasp.nvim",
    config = function()
        require("clasp").setup({
            pairs = { ["{"] = "}", ['"'] = '"', ["'"] = "'", ["("] = ")", ["["] = "]", ["<"] = ">" },
        })

        -- jumping from smallest region to largest region
        vim.keymap.set({ "n", "i" }, "<c-l>",function()
            require("clasp").wrap('next')
        end)

        -- jumping from largest region to smallest region
        vim.keymap.set({ "n", "i" }, "<c-l>",function()
            require("clasp").wrap('prev')
        end)

        -- If you want to exclude nodes whose end row is not current row
        vim.keymap.set({ "n", "i" }, "<c-l>",function()
            require("clasp").wrap('next', function(nodes)
                local n = {}
                for _, node in ipairs(nodes) do
                    if node.end_row == vim.api.nvim_win_get_cursor(0)[1] - 1 then
                        table.insert(n, node)
                    end
                end
                return n
            end)
        end)
    end,
}
```
## Limitations

If you use have multiple cursors, make sure you call `wrap` in normal mode.


## License

MIT License.
