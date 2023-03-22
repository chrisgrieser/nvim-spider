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
---@param reversed? any whether the search should take place backwards
---@return number|nil pattern position, returns nil if no pattern was found
local function nextWordPosition(str, startFrom, whichEnd, reversed)
	-- INFO `%f[set]` is the frontier pattern, roughly lua's version of `\b`
	local lowerWord = "%u?[%l%d]+" -- first char may be uppercase for CamelCase
	local upperWord = "%f[%w][%u%d]+%f[^%w]" -- uppercase for SCREAMING_SNAKE_CASE
	local punctuation = "%f[^%s]%p+%f[%s]" -- standalone punctuation

	if reversed then
		-- pattern needs to be reversed of input string for `b` and `ge`
		-- (the other patterns are "symmetric" and therefore do not require reversal)
		lowerWord = "[%l%d]+%u?"
		-- cut string to before cursor as `:find` cannot take an end location
		str = str:sub(1, startFrom):reverse()
		startFrom = 1
	end

	local lowerStart, lowerEnd = str:find(lowerWord, startFrom)
	local upperStart, upperEnd = str:find(upperWord, startFrom)
	local punctStart, punctEnd = str:find(punctuation, startFrom)

	local pos1, pos2, pos3
	if whichEnd == "end" then
		pos1 = lowerEnd
		pos2 = upperEnd
		pos3 = punctEnd
	else
		pos1 = lowerStart
		pos2 = upperStart
		pos3 = punctStart
	end
	if not (pos1 or pos2 or pos3) then return nil end
	pos1 = pos1 or math.huge -- math.huge will never be the smallest number
	pos2 = pos2 or math.huge
	pos3 = pos3 or math.huge

	local target = math.min(pos1, pos2, pos3)
	if reversed then target = #str - target + 1 end

	return target
end

--------------------------------------------------------------------------------

---search for the next item to move to
---@param key string e|w|b
function M.motion(key)
	if not (key == "w" or key == "e" or key == "b") then
		vim.notify("Invalid key: " .. key .. "\nOnly w, e, and b are supported.", vim.log.levels.ERROR)
		return
	end

	-- get line content to search
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = getline(row)

	-- key-specific-search
	local target
	if key == "e" then
		col = col + 2 -- 1 for next position, 1 for lua's 1-based indexing
		target = nextWordPosition(line, col, "end")
	elseif key == "w" then
		col = col + 1 -- one less, because the endOfWord cursor is standing on should be found
		local endOfWord = nextWordPosition(line, col, "end")
		if not endOfWord then return end
		endOfWord = endOfWord + 1 -- next position
		target = nextWordPosition(line, endOfWord, "start")
	elseif key == "b" then
		target = nextWordPosition(line, col, "end", "reversed")
	end

	-- move to new location
	if not target then return end -- not found in this line

	local isOperatorPending = vim.api.nvim_get_mode().mode == "no"
	if not isOperatorPending then target = target - 1 end -- lua string indices different

	vim.api.nvim_win_set_cursor(0, { row, target })
end

--------------------------------------------------------------------------------
return M
