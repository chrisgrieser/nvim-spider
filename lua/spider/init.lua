local utf8 = require("lua-utf8")

local M = {}
local patternVariants = require("spider.pattern-variants")

--------------------------------------------------------------------------------
-- CONFIG
---@class (exact) optsObj
---@field skipInsignificantPunctuation boolean
---@field subwordMovement boolean
---@field customPatterns string[]

---@type optsObj
local defaultOpts = {
	skipInsignificantPunctuation = true,
	subwordMovement = true,
	customPatterns = {},
}
local globalOpts = defaultOpts

---@param userOpts optsObj
function M.setup(userOpts) globalOpts = vim.tbl_deep_extend("force", defaultOpts, userOpts) end

--------------------------------------------------------------------------------

---Equivalent to fn.getline(), but using more efficient nvim api.
---@param lnum number
---@nodiscard
---@return string
local function getline(lnum)
	local lineContent = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)
	return lineContent[1]
end

-- INFO This method is necessary as opposed to a simple `:find`, to correctly
-- determine a word the cursor is already standing on.
---@param line string
---@param pattern string
---@param endOfWord boolean look for the end of the pattern instead of the start
---@param offset number -- look for the first match after this number
---@nodiscard
---@return number|nil returns nil if none is found
local function firstMatchAfter(line, pattern, endOfWord, offset)
	-- special case: pattern with ^/$, since there can only be one match
	-- and since gmatch won't work with them
	if pattern:find("^%^") or pattern:find("%$$") then
		if pattern:find("%$$") and offset > utf8.len(line) then return nil end -- checking for high col count for virtualedit
		if pattern:find("^%^") and offset ~= 0 then return nil end

		local start, endPos = utf8.find(line, pattern)
		if start == nil or endPos == nil then return nil end

		local pos = endOfWord and endPos or start
		return pos
	end

	if endOfWord then
		pattern = pattern .. "()" -- INFO "()" makes gmatch return the position of that group
	else
		pattern = "()" .. pattern
	end
	-- `:gmatch` will return all locations in the string where the pattern is
	-- found, the loop looks for the first one that is higher than the offset
	-- to look from
	for pos in utf8.gmatch(line, pattern) do
		if endOfWord then pos = pos - 1 end
		if pos > offset then return pos end
	end
	return nil
end

---@param line string input string where to find the pattern
---@param offset number position to start looking from
---@param key "w"|"e"|"b"|"ge" the motion to perform
---@param opts optsObj configuration table as in setup()
---@nodiscard
---@return number|nil pattern position, returns nil if no pattern was found
local function getNextPosition(line, offset, key, opts)
	local endOfWord = (key == "ge") or (key == "e")
	local backwards = (key == "b") or (key == "ge")
	local patterns = patternVariants.get(opts, backwards)

	if backwards then
		line = utf8.reverse(line)
		endOfWord = not endOfWord

		local isSameLine = offset ~= 0
		if isSameLine then offset = utf8.len(line) - offset + 1 end
	end

	-- search for patterns, get closest one
	local matches = {}
	for _, pattern in pairs(patterns) do
		local match = firstMatchAfter(line, pattern, endOfWord, offset)
		if match then table.insert(matches, match) end
	end
	if vim.tbl_isempty(matches) then return nil end -- none found in this line
	local nextPos = math.min(unpack(matches))

	if backwards then nextPos = utf8.len(line) - nextPos + 1 end
	return nextPos
end

--------------------------------------------------------------------------------

---@param key "w"|"e"|"b"|"ge" the motion to perform
---@param motionOpts? optsObj configuration table as in setup()
function M.motion(key, motionOpts)
	local opts = motionOpts and vim.tbl_deep_extend("force", globalOpts, motionOpts) or globalOpts

	-- GUARD: validate motion parameter
	if not (key == "w" or key == "e" or key == "b" or key == "ge") then
		vim.notify(
			"Invalid key: " .. key .. "\nOnly w, e, b, and ge are supported.",
			vim.log.levels.ERROR,
			{ title = "nvim-spider" }
		)
		return
	end

	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local startRow = row
	local lastRow = vim.fn.line("$")
	local forwards = key == "w" or key == "e"

	local line = getline(row)
	local offset = 1
	for p, _ in utf8.codes(getline(row)) do
		if p > col then break end
		offset = offset + 1
	end
	local startOffset = offset

	-- looping through counts
	for _ = 1, vim.v.count1, 1 do
		-- looping through rows (if next location not found in line)
		while true do
			local result = getNextPosition(line, offset, key, opts)
			if result then
				offset = result
				local onTheSamePos = (offset == startOffset and row == startRow)
				if not onTheSamePos then break end
			end

			offset = 0
			row = forwards and row + 1 or row - 1
			if row > lastRow or row < 1 then return end
			line = getline(row)
		end
	end

	col = utf8.offset(line, offset) - 1 -- lua string indices different

	-- operator-pending specific considerations (see issues #3 and #5)
	local mode = vim.api.nvim_get_mode().mode
	local isOperatorPending = mode == "no" -- = [n]ormal & [o]perator, not the word "no"
	if isOperatorPending then
		local lastCol = vim.fn.col("$")
		if key == "e" then
			offset = offset + 1
			col = utf8.offset(line, offset) - 1
		end

		if lastCol - 1 == col then
			-- HACK columns are end-exclusive, cannot actually target the last character
			-- in the line otherwise without switching to visual mode?!
			vim.cmd.normal { "v", bang = true }
			offset = offset - 1
			col = utf8.offset(line, offset) - 1 -- SIC indices in visual off-by-one compared to normal
		end
	end

	-- consider opt.foldopen
	local shouldOpenFold = vim.tbl_contains(vim.opt_local.foldopen:get(), "hor")
	if mode == "n" and shouldOpenFold then vim.cmd.normal { "zv", bang = true } end

	vim.api.nvim_win_set_cursor(0, { row, col })
end

--------------------------------------------------------------------------------
return M
