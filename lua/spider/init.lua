local M = {}
local patternVariants = require("lua.spider.pattern-variants")

--------------------------------------------------------------------------------
-- CONFIG
---@class optsObj
---@field skipInsignificantPunctuation boolean defaults to true

-- Default values
local defaults = {
	skipInsignificantPunctuation = true,
}
local config = defaults

---@param opts optsObj
function M.setup(opts) config = vim.tbl_deep_extend("force", config, opts) end

--------------------------------------------------------------------------------

---equivalent to fn.getline(), but using more efficient nvim api
---@param lnum number
---@nodiscard
---@return string
local function getline(lnum)
	local lineContent = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)
	return lineContent[1]
end

-- INFO This method is necessary as opposed to a simple `:find`, to correctly
-- determine a word the cursor is already standing on
---@param line string
---@param pattern string
---@param endOfWord boolean look for the end of the pattern instead of the start
---@param col number -- look for the first match after this number
---@nodiscard
---@return number|nil returns nil if none is found
local function firstMatchAfter(line, pattern, endOfWord, col)
	-- special case: pattern with ^/$, since there can only be one match
	-- and since gmatch won't work with them
	if pattern:find("^%^") or pattern:find("%$$") then
		if pattern:find("%$$") and col >= #line then return nil end -- checking for high col count for virtualedit
		if pattern:find("^%^") and col ~= 1 then return nil end
		local start, endPos = line:find(pattern)
		local pos = endOfWord and endPos or start
		if pos and not endOfWord then pos = pos - 1 end
		return pos
	end

	if endOfWord then
		pattern = pattern .. "()" -- INFO "()" makes gmatch return the position of that group
	else
		pattern = "()" .. pattern
	end
	-- `:gmatch` will return all locations in the string where the pattern is
	-- found, the loop looks for the first one that is higher than the col to
	-- look from
	for pos in line:gmatch(pattern) do
		if endOfWord and pos > col then return pos - 1 end
		if not endOfWord and pos >= col then return pos - 1 end
	end
	return nil
end

---finds next word, which is lowercase, uppercase, or standalone punctuation
---@param line string input string where to find the pattern
---@param col number position to start looking from
---@param key "w"|"e"|"b"|"ge" the motion to perform
---@param opts optsObj configuration table as in setup()
---@nodiscard
---@return number|nil pattern position, returns nil if no pattern was found
local function getNextPosition(line, col, key, opts)
	local patterns = patternVariants.get(opts)

	-- define motion properties
	local backwards = (key == "b") or (key == "ge")
	local endOfWord = (key == "ge") or (key == "e")
	if backwards then
		patterns.camelCaseWord = patterns.camelCaseWordReversed
		line = line:reverse()
		endOfWord = not endOfWord
		if col == -1 then
			col = 1
		else
			col = #line - col + 1
		end
	end

	-- search for patterns, get closest one
	local matches = {}
	for _, pattern in pairs(patterns) do
		local match = firstMatchAfter(line, pattern, endOfWord, col)
		if match then table.insert(matches, match) end
	end
	if vim.tbl_isempty(matches) then return nil end -- none found in this line
	local nextPos = math.min(unpack(matches))

	if not endOfWord then nextPos = nextPos + 1 end
	if backwards then nextPos = #line - nextPos + 1 end
	return nextPos
end

--------------------------------------------------------------------------------

---@param key "w"|"e"|"b"|"ge" the motion to perform
---@param opts? optsObj configuration table as in setup()
function M.motion(key, opts)
	-- merge global opts with opts passed for the specific call
	opts = opts and vim.tbl_deep_extend("force", config, opts) or config

	-- GUARD
	if not (key == "w" or key == "e" or key == "b" or key == "ge") then
		vim.notify(
			"Invalid key: " .. key .. "\nOnly w, e, b, and ge are supported.",
			vim.log.levels.ERROR,
			{ title = "nvim-spider" }
		)
		return
	end

	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local startCol, startRow = col, row
	local lastRow = vim.api.nvim_buf_line_count(0)
	local forwards = key == "w" or key == "e"

	-- looping through counts
	for i = 1, vim.v.count1, 1 do
		if forwards then
			col = col + 2 -- +1 (next position), +1 lua indexing
		elseif not forwards and i > 1 then
			col = col - 1 -- next pos
		end

		-- looping through rows (if next location not found in line)
		while true do
			local line = getline(row)
			col = getNextPosition(line, col, key, opts)
			local onTheSamePos = (col == startCol + 1 and row == startRow)
			if col and not onTheSamePos then break end
			col = forwards and 1 or -1
			row = forwards and row + 1 or row - 1
			if row > lastRow or row < 1 then return end
		end
	end

	col = col - 1 -- lua string indices different

	-- operator-pending specific considerations (see issues #3 and #5)
	local mode = vim.api.nvim_get_mode().mode
	local isOperatorPending = mode == "no"
	if isOperatorPending then
		local lastCol = vim.fn.col("$")
		if key == "e" then col = col + 1 end

		if lastCol - 1 == col then
			-- HACK columns are end-exclusive, cannot actually target the last character
			-- in the line otherwise without switching to visual mode?!
			vim.cmd.normal { "v", bang = true }
			col = col - 1 -- SIC indices in visual off-by-one compared to normal
		end
	end

	-- consider opt.foldopen
	local shouldOpenFold = vim.tbl_contains(vim.opt_local.foldopen:get(), "hor")
	if mode == "n" and shouldOpenFold then vim.cmd.normal { "zv", bang = true } end

	vim.api.nvim_win_set_cursor(0, { row, col })
end

--------------------------------------------------------------------------------
return M
