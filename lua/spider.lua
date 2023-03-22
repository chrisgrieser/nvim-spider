local M = {}

---equivalent to fn.getline(), but using more efficient nvim api
---@param lnum integer
---@return string
local function getline(lnum)
	local lineContent = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)
	return lineContent[1]
end

---finds next word, which is lowercase, uppercase, or standalone punctuation
---@param str string input string where to find the pattern
---@param startFrom number position to start looking from
---@param whichEnd? string start|end whether to return the start or the end of
---where the pattern was found, defaults to "start"
---@param standingOnPunct boolean
---@param reversed? any whether the search should take place backwards
---@return number|nil pattern position, returns nil if no pattern was found
local function getNextPosition(str, startFrom, whichEnd, standingOnPunct, reversed)
	-- INFO `%f[set]` is the frontier pattern, roughly lua's version of `\b`
	local lowerWord = "%u?[%l%d]+" -- first char may be uppercase for CamelCase
	local upperWord = "%f[%w][%u%d]+%f[^%w]" -- uppercase for SCREAMING_SNAKE_CASE
	local punctuation = "%f[^%s]%p+%f[%s]" -- punctuation surrounded by whitespace

	if reversed then
		lowerWord = "[%l%d]+%u?" -- pattern needs to be reversed of input string for `b` and `ge`
		upperWord = "%f[%w]%u[%u%d]*" -- no %f[] at the end to also match uppercase next to the cursor
		-- workaround since lua's find can only limit searching to a start-indice,
		-- but not an end
		str = str:sub(1, startFrom):reverse()
		startFrom = 1
	end

	local pos1, pos2, pos3, pos4
	local lowerStart, lowerEnd = str:find(lowerWord, startFrom)
	local upperStart, upperEnd = str:find(upperWord, startFrom)
	local punctStart, punctEnd = str:find(punctuation, startFrom)
	if whichEnd == "end" then
		pos1 = lowerEnd
		pos2 = upperEnd
		pos3 = punctEnd
	else
		pos1 = lowerStart
		pos2 = upperStart
		pos3 = punctStart
	end
	if standingOnPunct then -- punctuation at beginning only considered when standing on punctuation
		local punctuation2 = "^%p+%f[%s]" -- needs extra pattern since %f[] does not match ^
		local punct2Start, punct2End = str:find(punctuation2, startFrom)
		pos4 = whichEnd == "end" and punct2End or punct2Start
	end

	-- get the minimum, but factor in that any could be nil
	if not (pos1 or pos2 or pos3 or pos4) then return nil end
	pos1 = pos1 or math.huge -- math.huge will never be the smallest number
	pos2 = pos2 or math.huge
	pos3 = pos3 or math.huge
	pos4 = pos4 or math.huge
	local target = math.min(pos1, pos2, pos3, pos4)

	if reversed then target = #str - target + 1 end
	return target
end

--------------------------------------------------------------------------------

---search for the next item to move to
---@param key string e|w|b
function M.motion(key)
	if not (key == "w" or key == "e" or key == "b" or key == "ge") then
		vim.notify("Invalid key: " .. key .. "\nOnly w, e, b, and ge are supported.", vim.log.levels.ERROR)
		return
	end

	-- get line content to search
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = getline(row)
	local standingOnPunct = line:sub(col + 1, col + 1):find("%p") ~= nil

	-- key-specific-search
	local target
	if key == "e" then
		col = col + 2 -- 1 for next position, 1 for lua's 1-based indexing
		target = getNextPosition(line, col, "end", standingOnPunct)
	elseif key == "w" then
		col = col + 1 -- one less, because the endOfWord cursor is standing on should be found
		local endOfWord = getNextPosition(line, col, "end", standingOnPunct)
		if not endOfWord then return end
		endOfWord = endOfWord + 1 -- next position
		target = getNextPosition(line, endOfWord, "start", standingOnPunct)
	elseif key == "b" then
		target = getNextPosition(line, col, "end", standingOnPunct, "reversed")
	elseif key == "ge" then
		-- BUG "ge" still has has some edge cases
		local startOfWord = getNextPosition(line, col, "end", standingOnPunct, "reversed")
		if not startOfWord then return end
		startOfWord = startOfWord - 1 -- next position
		target = getNextPosition(line, startOfWord, "start", standingOnPunct, "reversed")
	end

	-- move to new location
	if not target then return end -- not found in this line

	local isOperatorPending = vim.api.nvim_get_mode().mode == "no"
	if not isOperatorPending then target = target - 1 end -- lua string indices different

	vim.api.nvim_win_set_cursor(0, { row, target })
end

--------------------------------------------------------------------------------
return M
