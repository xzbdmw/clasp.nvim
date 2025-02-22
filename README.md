# Clasp ⎇
**Cl**ever **A**daptive **S**urround **P**airs

A pair wrapping plugin with:
* **Fix up missing pairs** (`{}`, `""`, `()`...)
* **Incremental node traversal** (TS-powered)
* **Multi-cursor** aware, works with [multicursor.nvim](https://github.com/jake-stewart/multicursor.nvim)
* **Non-destructive editing** (preserves undo history)

## Show case with multicursor.nvim


https://github.com/user-attachments/assets/b5e4a531-16ce-4d32-89e9-22b85b071e29



## Installation

With **lazy.nvim**:

```lua
return {
    "xzbdmw/clasp.nvim",
    config = function()
        -- You don't need to set these options.
        require("clasp").setup({})
        vim.keymap.set({ "n", "i" }, "<c-l>",function()
            require("clasp").jump()
        end)
    end,
}
```


## License

MIT License.
