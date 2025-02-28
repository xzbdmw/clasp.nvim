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
            -- If called from insert mode, do not return to normal mode.
            keep_insert_mode = true,
            -- consider the following go code:
            --
            -- `var s make()[]int`
            --
            -- if we want to turn it into:
            --
            -- `var s make([]int)`
            --
            -- Directly parse would produce wrong nodes, so clasp always removes the
            -- entire pair (`()` in this case) before parsing, in this case what the
            -- parser would see is `var s make[]int`, but this is still not valid
            -- grammar. For a better parse tree, we can aggressively remove all
            -- alphabetic chars before cursor, so it becomes:
            --
            -- `var s []int`
            --
            -- Now we can correctly wrap the entire `[]int`, because it is identified
            -- as a node. By default we only remove current pair(s) before parsing, in
            -- most cases this is fine, but you can set `remove_pattern = "[a-zA-Z_%-]+$"`
            -- to use a more aggressive approach if you run into problems.
            remove_pattern = nil,
        })

        -- jumping from smallest region to largest region

        -- Initial state:
        -- func(|)vim.keymap.foo('bar')

        -- Keep pressing <c-l>:
        -- func(vim)|.keymap.foo('bar')
        -- func(vim.keymap)|.foo('bar')
        -- func(vim.keymap.foo('bar'))|
        vim.keymap.set({ "n", "i" }, "<c-l>", function()
            require("clasp").wrap('next')
        end)

        -- jumping from largest region to smallest region

        -- Initial state:
        -- func(|)vim.keymap.foo('bar')

        -- Keep pressing <c-;>
        -- func(vim.keymap.foo('bar'))|
        -- func(vim.keymap)|.foo('bar')
        -- func(vim)|.keymap.foo('bar')
        -- func(|)vim.keymap.foo('bar')
        vim.keymap.set({ "n", "i" }, "<c-;>", function()
            require("clasp").wrap('prev')
        end)

        -- If you want to exclude nodes whose end row is not current row
        vim.keymap.set({ "n", "i" }, "<c-l>", function()
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

If you have multiple cursors, make sure you call `wrap` in normal mode.

## Similar plugins

- [ultimate-autopair.nvim](https://github.com/altermo/ultimate-autopair.nvim)
    - Uses a regex heuristic combined with already
      matched pairs to determine right pair position, while this plugin relies solely on
      treesitter. This makes it jumps more aggressive and allows `wrap('prev')`
      to jump from a large region to a smaller one as the possible positions
      are known when parsing over. The downside is sometimes treesitter does
      not have a valid parse tree so position may be wrong compared to regex solution.
    - The main motivation for writting this plugin is to support multi-cursor. So
      it works on normal mode and remembers each cursor's parsing state.
- [nvim-autopairs](https://github.com/windwp/nvim-autopairs)
    - Uses hint based fast wrap, each possible position has one label, only works for current line.

## License

MIT License.
