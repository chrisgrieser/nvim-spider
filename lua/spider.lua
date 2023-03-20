local M = {}

-- HELPERS

---equivalent to fn.getline(), but using more efficient nvim api
---@param lnum integer
---@return string
local function getline(lnum)
	local lineContent = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)
	return lineContent[1]
end

---get the minimum of the three positions, considering that any may be nil
---@param pos1 number|nil
---@param pos2 number|nil
---@param pos3 number|nil
---@return number|nil returns nil of all numbers are nil, and also sends notification
local function minimum(pos1, pos2, pos3)
	if not (pos1 or pos2 or pos3) then 
		-- vim.notify("None found in this line.", vim.log.levels.WARN)
		return nil
	end
	pos1 = pos1 or math.huge -- math.huge will never be the smallest number
	pos2 = pos2 or math.huge
	pos3 = pos3 or math.huge
	return math.min(pos1, pos2, pos3)
end

--------------------------------------------------------------------------------

-- PATTERNS
local lowerWord = "%u?[%l%d]+" -- first char may be uppercase for CamelCase
local upperWord = "[%u%d][%u%d]+" -- at least two, needed for SCREAMING_SNAKE_CASE

---minimum punctuation configurable by user, default is 3
---@return string lua pattern for finding punctuation
local function getPunctuationPattern()
	local default = 3
	local minimum_punctuation = vim.g.spider_minimum_punctuation or default
	return ("[%p]"):rep(minimum_punctuation) .. "+"
end

--------------------------------------------------------------------------------

---search for the next item to move to
---@param key string e|w|b
function M.motion(key)
	if not (key == "w" or key == "e" or key == "b") then
		vim.notify("Invalid key: " .. key .. "\nOnly w, e, and b are supported.", vim.log.levels.ERROR)
		return
	end
	local punctuation = getPunctuationPattern()
	local closestPos, lowerPos, upperPos, punctPos

	-- get line content to search
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = getline(row)

	-- search
	if key == "w" or key == "e" then
		col = col + 2 -- next pos
		-- determine end of word
		_, lowerPos = line:find(lowerWord, col)
		_, upperPos = line:find(upperWord, col)
		_, punctPos = line:find(punctuation, col)
		local endOfWord = minimum(lowerPos, upperPos, punctPos)
		if not endOfWord then return end
		if key == "w" then
			endOfWord = endOfWord + 1 -- next position
			-- determine start of next word
			lowerPos, _ = line:find(lowerWord, endOfWord)
			upperPos, _ = line:find(upperWord, endOfWord)
			punctPos, _ = line:find(punctuation, endOfWord)
			closestPos = minimum(lowerPos, upperPos, punctPos)
		elseif key == "e" then
			closestPos = endOfWord
		end
	elseif key == "b" then
		line = line
			:sub(1, col) -- only before the cursor pos
			:reverse() -- search backwards to avoid need for loop
		lowerWord = "[%l%d]+%u?" -- adjustment needed due to reversal
		_, lowerPos = line:find(lowerWord)
		_, upperPos = line:find(upperWord)
		_, punctPos = line:find(punctuation)
		closestPos = minimum(lowerPos, upperPos, punctPos)
		if closestPos then closestPos = #line - closestPos + 1 end -- needed due to reversal
	end

	-- move to new location
	if not closestPos then return end
	closestPos = closestPos - 1
	if vim.fn.mode() == "o" then vim.cmd.normal { "v", bang = true } end
	vim.api.nvim_win_set_cursor(0, { row, closestPos })
end

--------------------------------------------------------------------------------
return M
