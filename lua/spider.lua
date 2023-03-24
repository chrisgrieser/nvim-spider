local M = {}

--------------------------------------------------------------------------------
-- HELPERS

---equivalent to fn.getline(), but using more efficient nvim api
---@param lnum integer
---@return string
local function getline(lnum)
	local lineContent = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)
	return lineContent[1]
end

---minimum, factoring in that any number may be null
---@param pos1 number|nil
---@param pos2 number|nil
---@param pos3 number|nil
---@return number|nil minimum value or nil if all input numbers are nil
local function minimum(pos1, pos2, pos3)
	if not (pos1 or pos2 or pos3) then return nil end
	pos1 = pos1 or math.huge -- math.huge will never be the lowest number
	pos2 = pos2 or math.huge
	pos3 = pos3 or math.huge
	return math.min(pos1, pos2, pos3)
end

---returns the index of the first match after the given pattern
---@param line string
---@param pattern string
---@param startOrEnd string start|end whether the start of the end of the pattern should be looked for
---@param col number
---@return number|nil returns nil if none is found
local function firstMatchAfter(line, pattern, startOrEnd, col)
	if startOrEnd == "start" then
		pattern = "()" .. pattern
	else
		pattern = pattern .. "()"
	end
	for pos in line:gmatch(pattern) do
		if pos > col then return pos - 1 end
	end
	return nil
end

--------------------------------------------------------------------------------

---finds next word, which is lowercase, uppercase, or standalone punctuation
---@param line string input string where to find the pattern
---@param col number position to start looking from
---@param startOrEnd string start|end whether to return the start or the end of where the pattern was found, defaults to "start"
---@param reversed? any whether the search should take place backwards
---@return number|nil pattern position, returns nil if no pattern was found
local function getNextPosition(line, col, startOrEnd, reversed)
	-- INFO `%f[set]` is the frontier pattern, roughly lua's version of `\b`
	local lowerWord = "%u?[%l%d]+" -- first char may be uppercase for CamelCase
	local upperWord = "%f[%w][%u%d]+%f[^%w]" -- uppercase for SCREAMING_SNAKE_CASE
	local punctuation = "%f[^%s]%p+%f[%s]" -- punctuation surrounded by whitespace

	-- reverse pattern, line, and colNum for `b` and `ge`
	if reversed then
		lowerWord = "[%l%d]+%u?" -- the other patterns are already symmetric
		line = line:reverse()
		col = #line - col + 1
	end
	-- line = line .. " " -- so the 2nd %f[] also matches the end of the string

	local pos1 = firstMatchAfter(line, lowerWord, startOrEnd, col)
	local pos2 = firstMatchAfter(line, upperWord, startOrEnd, col)
	local pos3 = firstMatchAfter(line, punctuation, startOrEnd, col)

	local nextPos = minimum(pos1, pos2, pos3)
	if not nextPos then return nil end

	if reversed then nextPos = #line - nextPos + 1 end
	if startOrEnd == "start" then nextPos = nextPos + 1 end
	return nextPos
end

--------------------------------------------------------------------------------

---search for the next item to move to
---@param key string e|w|b|ge
function M.motion(key)
	if not (key == "w" or key == "e" or key == "b" or key == "ge") then
		vim.notify("Invalid key: " .. key .. "\nOnly w, e, b, and ge are supported.", vim.log.levels.ERROR)
		return
	end

	-- get line content to search
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = getline(row)

	-- key-specific-search
	local target
	if key == "e" then
		col = col + 2 -- 1 for next position, 1 for lua's 1-based indexing
		target = getNextPosition(line, col, "end")
	elseif key == "w" then
		col = col + 1 -- one less, because the endOfWord cursor is standing on should be found
		target = getNextPosition(line, col, "start")
	elseif key == "b" then
		target = getNextPosition(line, col, "end", "reversed")
	elseif key == "ge" then
		col = col - 1 
		target = getNextPosition(line, col, "start", "reversed")
	end

	-- move to new location
	if not target then return end -- not found in this line

	local isOperatorPending = vim.api.nvim_get_mode().mode == "no"
	if not isOperatorPending then target = target - 1 end -- lua string indices different

	vim.api.nvim_win_set_cursor(0, { row, target })
end

--------------------------------------------------------------------------------
return M
