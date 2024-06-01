local M = {}
local patternVariants = require("spider.pattern-variants")
local operatorPending = require("spider.operator-pending")

--------------------------------------------------------------------------------
-- UTF-8 SUPPORT

local originalLuaStringFuncs = {
	reverse = string.reverse,
	find = string.find,
	gmatch = string.gmatch,
	len = string.len,
	init_pos = function(_, col)
		col = col + 1 -- from 0-based indexing to 1-based
		local startCol = col
		return col, startCol
	end,
	offset = function(_, pos) return pos end,
}

local luaUtf8Installed, utf8 = pcall(require, "lua-utf8")
local stringFuncs = {}

if not luaUtf8Installed then
	stringFuncs = originalLuaStringFuncs
else
	for name, _ in pairs(originalLuaStringFuncs) do
		if utf8[name] then stringFuncs[name] = utf8[name] end
	end
	stringFuncs.init_pos = function(s, col)
		local offset = 1
		for p, _ in utf8.codes(s) do
			if p > col then break end
			offset = offset + 1
		end
		local startOffset = offset
		return offset, startOffset
	end
end

--------------------------------------------------------------------------------
---@class customPatterns
---@field patterns string[]? string array of lua patterns to match against.
---@field overrideDefault boolean? set to false to extend the default patterns with customPatterns. Defaults to true.

-- CONFIG
---@class (exact) optsObj
---@field skipInsignificantPunctuation boolean?
---@field subwordMovement boolean? determines movement through camelCase and snake_case. Defaults to true.
---@field customPatterns customPatterns|string[]? user defined patterns to match for motion movement

---@type optsObj
local defaultOpts = {
	skipInsignificantPunctuation = true,
	consistentOperatorPending = false,
	subwordMovement = true,
	customPatterns = {
		patterns = {},
		overrideDefault = true,
	},
}
local globalOpts = defaultOpts

---@param userOpts? optsObj
function M.setup(userOpts)
	globalOpts = vim.tbl_deep_extend("force", defaultOpts, userOpts or {})
end

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
		if pattern:find("%$$") and offset > stringFuncs.len(line) then return nil end -- checking for high col count for virtualedit
		if pattern:find("^%^") and offset ~= 0 then return nil end

		local start, endPos = stringFuncs.find(line, pattern)
		if start == nil or endPos == nil then return nil end

		local pos = endOfWord and endPos or start
		if pos > offset then return pos
		else return nil end
	end

	if endOfWord then
		pattern = pattern .. "()" -- INFO "()" makes gmatch return the position of that group
	else
		pattern = "()" .. pattern
	end
	-- `:gmatch` will return all locations in the string where the pattern is
	-- found, the loop looks for the first one that is higher than the offset
	-- to look from
	for pos in stringFuncs.gmatch(line, pattern) do
		if type(pos) == "string" then return nil end

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
		line = stringFuncs.reverse(line)
		endOfWord = not endOfWord

		local isSameLine = offset ~= 0
		if isSameLine then offset = stringFuncs.len(line) - offset + 1 end
	end

	-- search for patterns, get closest one
	local matches = {}
	for _, pattern in pairs(patterns) do
		local match = firstMatchAfter(line, pattern, endOfWord, offset)
		if match then table.insert(matches, match) end
	end
	if vim.tbl_isempty(matches) then return nil end -- none found in this line
	local nextPos = math.min(unpack(matches))

	if backwards then nextPos = stringFuncs.len(line) - nextPos + 1 end
	return nextPos
end

local function normal(keys) vim.cmd.normal { keys, bang = true } end

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

	local start_pos = vim.api.nvim_win_get_cursor(0)
	local row, col = unpack(start_pos)
	local lastRow = vim.api.nvim_buf_line_count(0)
	local forwards = key == "w" or key == "e"

	local line = getline(row)
	local offset, _ = stringFuncs.init_pos(line, col)

	-- looping through counts
	for _ = 1, vim.v.count1, 1 do
		-- looping through rows (if next location not found in line)
		while true do
			local result = getNextPosition(line, offset, key, opts)
			if result then
				offset = result
				break
			end

			offset = 0
			row = forwards and row + 1 or row - 1
			if row > lastRow or row < 1 then return end
			line = getline(row)
		end
	end

	col = stringFuncs.offset(line, offset) - 1 -- lua string indices different

	-- operator-pending specific considerations (see issues #3 and #5)
	local mode = vim.api.nvim_get_mode().mode
	if opts.consistentOperatorPending then
		if mode:sub(1, 2) == "no" then
			operatorPending.setEndpoints(start_pos, { row, col }, { inclusive = key == 'e' })
			return
		end
	else
		if mode == "no" then -- [n]ormal & [o]perator, not the word "no"
			if key == "e" then
				offset = offset + 1
				col = stringFuncs.offset(line, offset) - 1
			end

			if col == #line then
				-- HACK columns are end-exclusive, cannot actually target the last
				-- character in the line without switching to visual mode
				normal("v")
				offset = offset - 1
				col = stringFuncs.offset(line, offset) - 1 -- SIC indices in visual off-by-one compared to normal
			end
		end
	end

	-- respect `opt.foldopen = "hor"`
	local shouldOpenFold = vim.tbl_contains(vim.opt_local.foldopen:get(), "hor")
	if mode == "n" and shouldOpenFold then normal("zv") end

	vim.api.nvim_win_set_cursor(0, { row, col })
end

--------------------------------------------------------------------------------
return M
