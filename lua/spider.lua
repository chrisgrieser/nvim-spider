local M = {}

--------------------------------------------------------------------------------
-- HELPERS

---equivalent to fn.getline(), but using more efficient nvim api
---@param lnum number
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
---@param endOfWord boolean look for the end of the pattern instead of the start
---@param col number
---@return number|nil returns nil if none is found
local function firstMatchAfter(line, pattern, endOfWord, col)
	-- INFO "()" makes gmatch return the position of that group
	if endOfWord then
		pattern = pattern .. "()"
	else
		pattern = "()" .. pattern
	end
	-- `:gmatch` will return all locations in the string where the pattern is
	-- found, the loop looks for the first one that is higher than the col to
	-- look from
	for pos in line:gmatch(pattern) do
		if pos > col then return pos - 1 end
	end
	return nil
end

--------------------------------------------------------------------------------

---finds next word, which is lowercase, uppercase, or standalone punctuation
---@param line string input string where to find the pattern
---@param col number position to start looking from
---@param key string w|e|b|ge the motion to perform
---@return number|nil pattern position, returns nil if no pattern was found
local function getNextPosition(line, col, key)
	-- (INFO `%f[set]` is the frontier pattern, roughly lua's version of `\b`)
	local lowerWord = "%u?[%l%d]+" -- first char may be uppercase for CamelCase
	local upperWord = "%f[%w][%u%d]+%f[^%w]" -- uppercase for SCREAMING_SNAKE_CASE
	local punctuation = "%f[^%s]%p+%f[%s]" -- punctuation surrounded by whitespace

	-- define motion properties
	local backwards = (key == "b") or (key == "ge")
	local endOfWord = (key == "ge") or (key == "e")
	if backwards then
		lowerWord = "[%l%d]+%u?" -- the other patterns are already symmetric
		line = line:reverse()
		endOfWord = not endOfWord
		if col == -1 then
			col = 1
		else
			col = #line - col + 1
		end
	end
	line = line .. " " -- so the 2nd %f[] also matches the end of the string

	-- search for patterns, get closest one
	local pos1 = firstMatchAfter(line, lowerWord, endOfWord, col)
	local pos2 = firstMatchAfter(line, upperWord, endOfWord, col)
	local pos3 = firstMatchAfter(line, punctuation, endOfWord, col)
	local nextPos = minimum(pos1, pos2, pos3)
	if not nextPos then return nil end -- none found in this line

	if not endOfWord then nextPos = nextPos + 1 end
	if backwards then nextPos = #line - nextPos end
	return nextPos
end

--------------------------------------------------------------------------------

---@param key string w|e|b|ge
function M.motion(key)
	if not (key == "w" or key == "e" or key == "b" or key == "ge") then
		vim.notify("Invalid key: " .. key .. "\nOnly w, e, b, and ge are supported.", vim.log.levels.ERROR)
		return
	end

	local startRow, startCol = unpack(vim.api.nvim_win_get_cursor(0))
	local col = startCol
	if key == "w" or key == "e" then col = col + 2 end -- 1 for next position, 1 for lua's 1-based indexing
	local row = startRow
	local lastRow = vim.fn.line("$")
	local targetCol

	while true do
		local line = getline(row)
		targetCol = getNextPosition(line, col, key)
		if targetCol then break end

		if key == "w" or key == "e" then
			row = row + 1
			if row > lastRow then return end 
			col = 1 -- from second line on, always look from the beginning of the line
		elseif key == "b" or key == "ge" then
			row = row - 1
			if row < 1 then return end 
			col = -1
		end
	end

	local isOperatorPending = vim.api.nvim_get_mode().mode == "no"
	if not isOperatorPending then targetCol = targetCol - 1 end -- lua string indices different

	vim.api.nvim_win_set_cursor(0, { row, targetCol })
end

--------------------------------------------------------------------------------
return M
