---@alias clasp.Nodes {start_row: integer, start_col: integer, end_row: integer, end_col: integer}
local M = {}

---@class clasp.Config
---@field pairs table<string,string>
M.config = {
    pairs = { ["{"] = "}", ['"'] = '"', ["'"] = "'", ["("] = ")", ["["] = "]", ["<"] = ">" },
    -- If called from insert mode, do not return to normal mode.
    keep_insert_mode = true,
    remove_pattern = nil,
}

local state = {}
local link = {}
local mc_last_create_time = nil

M.clean = function()
    state = {}
    link = {}
end

---@param row integer
---@param col integer
---@return string, string, string
local function surrounding_char(row, col)
    if col > 0 then
        local x = vim.api.nvim_buf_get_text(0, row - 1, col - 1, row - 1, col + 3, {})[1]
        return x:sub(1, 1), x:sub(2, 2), x:sub(3, 3)
    else
        local x = vim.api.nvim_buf_get_text(0, row - 1, col, row - 1, col + 3, {})[1]
        return "", x:sub(1, 1), x:sub(2, 2)
    end
end

---@return integer, integer
local function get_cursor()
    local cursor_pos = vim.fn.getpos(".")
    local row = cursor_pos[2] - 1
    local col = cursor_pos[3] - 1
    return row, col
end

---@param id string
---@return string|nil
local function link_head(id)
    if link[id] == nil then
        return nil
    end
    if not M.in_multi_cursor() and link[id].line ~= vim.api.nvim_get_current_line() then
        return nil
    end
    local try = 0
    -- avoid dead loop
    while link[id] ~= nil and try < 30 do
        try = try + 1
        id = link[id].id
    end
    return id
end

---@param row integer
---@param col integer
---@return string
local cursor_id = function(row, col)
    return string.format("%d!!%d", row, col)
end

---@param row integer
---@param col integer
---@param nodes clasp.Nodes[]
---@return { first: boolean, end_row: integer, end_col: integer }|nil
local function prev_pos(row, col, nodes)
    for i, range in ipairs(nodes) do
        if (range.end_row == row and range.end_col < col) or (range.end_row < row) then
            return { first = i == 1, end_row = range.end_row, end_col = range.end_col }
        end
    end
    return nil
end

---@param row integer
---@param col integer
---@param nodes clasp.Nodes[]
---@param direction "next"|"prev"
---@return { first: boolean, end_row: integer, end_col: integer }|nil
local function next_pos(row, col, nodes, direction)
    if direction == "prev" then
        return prev_pos(row, col, nodes)
    end
    for i, range in ipairs(nodes) do
        if (range.end_row == row and range.end_col > col) or (range.end_row > row) then
            return { first = i == 1, end_row = range.end_row, end_col = range.end_col }
        end
    end
    return nil
end

---@return table
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

---@return table
local function reverse(tbl)
    local res = {}
    for i = #tbl, 1, -1 do
        res[#tbl - i + 1] = tbl[i]
    end
    return res
end

---@return boolean
function M.in_multi_cursor()
    return package.loaded["multicursor-nvim"] and require("multicursor-nvim").numCursors() > 1
end

---@param row integer
---@param col integer
local function clean_state(row, col)
    if not M.in_multi_cursor() then
        M.clean()
    else
        if mc_last_create_time == nil then
            mc_last_create_time = vim.uv.hrtime()
            return
        end
        -- This only fires upon pair state creation, so subsequent calls to
        -- `wrap` do not invalidate state.
        local duration = 0.000001 * (vim.loop.hrtime() - mc_last_create_time)
        if duration > 1000 then
            mc_last_create_time = vim.uv.hrtime()
            M.clean()
        end
    end
end

---@param direction "next"|"prev"
---@param filter (fun(node: clasp.Nodes[]): clasp.Nodes[])|nil
function M.wrap(direction, filter)
    direction = direction or "next"
    local row, col = get_cursor()

    if vim.fn.mode() == "i" then
        -- Break undo sequence, ensure 'u' keep the original pair.
        vim.cmd("let &undolevels = &undolevels")
        if not M.config.keep_insert_mode then
            vim.cmd("stopinsert")
        end
        col = col - 1
    end

    local head = link_head(cursor_id(row, col))
    -- undo can't put cursor pass to end of line in insert mode, so try next one.
    if head == nil and #vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] == col + 2 then
        head = link_head(cursor_id(row, col + 1))
        col = col + 1
    end
    if head == nil or state[head] == nil then
        clean_state(row, col)

        local cursor_left, cursor_char, right = surrounding_char(row + 1, col)
        if cursor_char ~= "" and M.config.pairs[cursor_left] == cursor_char and col > 0 then
            if vim.fn.mode() == "i" then
                vim.api.nvim_win_set_cursor(0, { row + 1, col })
            else
                vim.api.nvim_win_set_cursor(0, { row + 1, col - 1 })
            end
            M.wrap(direction, filter)
            return
        end

        if #vim.api.nvim_get_current_line() <= col + 2 then
            vim.notify("[clasp.nvim] cursor is at the end of the line", vim.log.levels.WARN)
            return
        end
        local expected = M.config.pairs[cursor_char]
        if expected == nil then
            vim.notify(string.format('[clasp.nvim] cursor sits on "%s", not a pair', cursor_char), vim.log.levels.WARN)
            return
        end

        if expected ~= right then
            -- (|text ->  |text
            vim.api.nvim_buf_set_text(0, row, col, row, col + 1, { "" })
        else
            -- (|)text -> |text
            vim.api.nvim_buf_set_text(0, row, col, row, col + 2, { "" })
        end

        local nodes
        if M.config.remove_pattern then
            local text = vim.api.nvim_buf_get_text(0, row, 0, row, col, {})[1]
            local removed_chars = text:match(M.config.remove_pattern)
            if removed_chars ~= nil then
                vim.api.nvim_buf_set_text(0, row, col - #removed_chars, row, col, { string.rep(" ", #removed_chars) })
            end
            nodes = deduplicate(M.get_nodes(row, col, filter))
            if removed_chars ~= nil then
                vim.api.nvim_buf_set_text(0, row, col - #removed_chars, row, col, { removed_chars })
            end
        else
            nodes = deduplicate(M.get_nodes(row, col, filter))
        end

        if direction == "prev" then
            nodes = reverse(nodes)
        end
        if head == nil then
            state[cursor_id(row, col)] = { nodes = nodes, direction = direction }
        else
            state[head] = { nodes = nodes, direction = direction }
        end

        local left_pair, right_pair = cursor_char, expected
        local pos = next_pos(row, col, nodes, "next")
        if pos == nil then
            return
        end

        M.execute(row, col, pos, cursor_char, expected)
    else
        if state[head].direction ~= direction then
            vim.cmd("undo")
            return
        end
        local _, cursor_char = surrounding_char(row + 1, col)
        local pos = next_pos(row, col, state[head].nodes, direction)
        if pos == nil then
            return
        end

        -- Clip current right pair
        M.execute(row, col, pos, nil, cursor_char)
    end
end

---@param pos { first: boolean, end_row: integer, end_col: integer }
---@param left_pair string|nil
---@param right_pair string
function M.execute(cur_row, cur_col, pos, left_pair, right_pair)
    vim.cmd([[norm! m']])
    local first, end_row, end_col = pos.first, pos.end_row, pos.end_col
    if first then
        -- |text -> (|text
        vim.api.nvim_buf_set_text(0, cur_row, cur_col, cur_row, cur_col, { left_pair })
    else
        -- )text -> |text
        vim.api.nvim_buf_set_text(0, cur_row, cur_col, cur_row, cur_col + 1, { "" })
    end
    -- |text -> |text)
    vim.api.nvim_buf_set_text(0, end_row, end_col, end_row, end_col, { right_pair })
    -- |text) -> text)|
    vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col })
    if link[cursor_id(end_row, end_col)] == nil then
        link[cursor_id(end_row, end_col)] = { id = cursor_id(cur_row, cur_col), line = vim.api.nvim_get_current_line() }
    end
    if vim.fn.mode() == "i" then
        vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col + 1 })
    end
    -- inline extmark may leave cursor in a wrong position in neovide
    vim.cmd("redraw")
end

---@param row integer
---@param col integer
---@param filter (fun(node: clasp.Nodes[]): clasp.Nodes[])|nil
---@return clasp.Nodes[]
function M.get_nodes(row, col, filter)
    local node_ranges = {}
    ---@cast node_ranges clasp.Nodes[]

    local ok = pcall(function()
        vim.treesitter.get_parser(0, vim.bo.filetype):parse()
    end)
    if not ok then
        return {}
    end
    local cursor_node = vim.treesitter.get_node({ ignore_injections = false })
    if not cursor_node then
        return {}
    end

    -- Traverse parents to collect increasing end positions
    local node = cursor_node
    row, col = cursor_node:range()
    while node do
        local start_row, start_col, end_row, end_col = node:range()
        if start_row == row then
            local n = { start_row = start_row, start_col = start_col, end_row = end_row, end_col = end_col }
            if end_row == row then
                n.end_col = n.end_col + 1
            end
            table.insert(node_ranges, n)
        end
        ---@diagnostic disable-next-line: cast-local-type
        node = node:parent()
    end

    -- At least include line ending
    if #node_ranges == 0 then
        table.insert(
            node_ranges,
            { start_row = row, start_col = col, end_row = row, end_col = #vim.api.nvim_get_current_line() }
        )
    end

    if type(filter) == "function" then
        node_ranges = filter(node_ranges)
    end

    return node_ranges
end

function M.setup(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
end

return M
