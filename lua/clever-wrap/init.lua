local M = {}
M.config = {}

local state = {}
local link = {}

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
    M.execute()
end)

local function surrounding_char()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local x = vim.api.nvim_buf_get_text(0, row - 1, col, row - 1, col + 2, {})[1]
    return x:sub(1, 1), x:sub(2, 2)
end

local function get_cursor()
    local cursor_pos = vim.fn.getpos(".")
    local row = cursor_pos[2] - 1
    local col = cursor_pos[3] - 1
    return row, col
end

local function link_start(id)
    if link[id] == nil then
        return nil
    end
    while link[id] ~= nil do
        id = link[id]
    end
    return id
end

local cursor_id = function(row, col)
    return string.format("%d!!%d", row, col)
end

local function next_pos(row, col, nodes)
    for i, range in ipairs(nodes) do
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
            -- state = {}
            -- link = {}
        end,
    })

    if vim.fn.mode() == "i" then
        vim.cmd("stopinsert")
    end

    local row, col = get_cursor()
    local head = link_start(cursor_id(row, col))
    if head == nil or state[head] == nil then
        local cur, next = surrounding_char()
        local what = pair[cur]
        if what == nil then
            vim.notify("[clever_wrap] Your cursor is not in a pair", vim.log.levels.WARN)
            return
        end
        if what ~= next then
            vim.fn.setreg("z", pair[cur], "v")
            FeedKeys('"_x', "nix")
        else
            FeedKeys('"_x"_x', "nix")
        end
        local cache_z_reg = vim.fn.getreginfo("z")
        vim.fn.setreg("z", ")", "v")
        vim.fn.setreg("f", "(", "v")
        local nodes = deduplicate(M.get_nodes(row, col))
        if head == nil then
            state[cursor_id(row, col)] = nodes
        else
            state[head] = nodes
        end
        -- vim.fn.setreg("z", cache_z_reg)
        local pos = next_pos(row, col, nodes)
        if pos == nil then
            return
        end
        M.execute(origin, pos)
    else
        local pos = next_pos(row, col, state[head])
        if pos == nil then
            return
        end
        M.execute(origin, pos)
    end
end

function M.execute(origin, pos)
    vim.cmd([[norm! m']])
    local pre_row, prev_col = get_cursor()
    local first, start_row, start_col, end_row, end_col = unpack(pos)
    local x = string.format(
        [[%s<cmd>lua %s <CR>"zp<cmd>lua vim.o.eventignore = "%s"<CR>]],
        first and '"fP' or '"_x',
        string.format("vim.api.nvim_win_set_cursor(0, { %d, %d })", start_row + 1, end_col),
        origin
    )
    FeedKeys(x, "nx")
    local row, col = get_cursor()
    link[string.format("%d!!%d", row, col)] = string.format("%d!!%d", pre_row, prev_col)
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
            table.insert(node_ranges, { start_row, start_col, end_row, end_col })
        end
        parent = parent:parent()
    end

    return node_ranges
end

return M
