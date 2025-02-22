local M = {}
M.config = {}

local state = {}

local pair = {
    ["{"] = "}",
    ['"'] = '"',
    ["("] = ")",
    ["["] = "]",
}

vim.keymap.set("n", "<d-o>", function()
    state = {}
end)
vim.keymap.set("n", "<d-u>", function()
    M.fuck()
end)

local function surrounding_char()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local x = vim.api.nvim_buf_get_text(0, row - 1, col, row - 1, col + 2, {})[1]
    return x:sub(1, 1), x:sub(2, 2)
end

local function next_pos()
    local cursor_pos = vim.fn.getpos(".")
    local row = cursor_pos[2] - 1
    local col = cursor_pos[3] - 1
    for i, range in ipairs(state) do
        local start_row, start_col, end_row, end_col = unpack(range)
        if (start_row == row and end_col > col) or (row > start_row) then
            return { i == 1, start_row, start_col, end_row, end_col }
        end
    end
    return nil
end

local function deduplicate(tbl)
    local seen = {}
    local result = {}
    for _, v in ipairs(tbl) do
        if not seen[v] then
            table.insert(result, v)
            seen[v] = true
        end
    end
    return result
end

function M.wrap()
    local origin = vim.o.eventignore
    vim.o.eventignore = "CursorMoved"
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = vim.api.nvim_create_augroup("clever_wrap", {}),
        once = true,
        callback = function()
            state = {}
        end,
    })

    if vim.fn.mode() == "i" then
        vim.cmd("stopinsert")
    end

    if #state == 0 then
        local cur, next = surrounding_char()
        local what = pair[cur] or ")"
        if what ~= next then
            vim.fn.setreg("z", pair[cur], "v")
            FeedKeys('"_x', "nix")
        else
            FeedKeys('"_x"_x', "nix")
        end
        -- vim.schedule(function()
        M.fuck(origin)
        -- end)
    else
        M.fuck(origin)
    end
end

function M.fuck(origin)
    local cache_z_reg = vim.fn.getreginfo("z")
    vim.fn.setreg("z", ")", "v")
    -- vim.fn.setreg("z", cache_z_reg)
    if #state == 0 then
        local cursor_pos = vim.fn.getpos(".")
        local row = cursor_pos[2] - 1
        local col = cursor_pos[3] - 1
        local ranges = deduplicate(M.get_nodes(row, col))
        state = ranges
    end
    local pos = next_pos()
    if pos == nil then
        return
    end
    vim.cmd([[norm! m']])
    local first, start_row, start_col, end_row, end_col = unpack(pos)
    FeedKeys(
        string.format(
            [[%s<cmd>lua %s <CR>"zp<cmd>lua vim.o.eventignore = "%s"<CR>]],
            first and 'h"_x' or '"_x',
            string.format("vim.api.nvim_win_set_cursor(0, { %d, %d })", start_row + 1, end_col - 1),
            origin
        ),
        "n"
    )
end

function M.get_nodes(row, col)
    local node_ranges = {}

    local ts_utils = require("nvim-treesitter.ts_utils")
    -- Get initial node at cursor
    local cursor_node = ts_utils.get_node_at_cursor()
    if not cursor_node then
        return {}
    end

    -- Traverse parents to collect increasing end positions
    local parent = cursor_node
    while parent do
        local start_row, start_col, end_row, end_col = parent:range()
        if start_row == row and start_col == col then
            if end_row == start_row then
                table.insert(node_ranges, { start_row, start_col, end_row, end_col - 1 })
            else
                table.insert(node_ranges, { start_row, start_col, end_row, end_col })
            end
        end
        parent = parent:parent()
    end

    for _, node in ipairs(node_ranges) do
        print(vim.inspect(node))
    end
    return node_ranges
end

return M
