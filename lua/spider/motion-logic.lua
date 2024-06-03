local M = {}
local strFuncs = require("spider.utf8-support").stringFuncs
--------------------------------------------------------------------------------

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
		if pattern:find("%$$") and offset > strFuncs.len(line) then return nil end -- checking for high col count for virtualedit
		if pattern:find("^%^") and offset ~= 0 then return nil end

		local start, endPos = strFuncs.find(line, pattern)
		if start == nil or endPos == nil then return nil end

		local pos = endOfWord and endPos or start
		if pos > offset then
			return pos
		else
			return nil
		end
	end

	if endOfWord then
		pattern = pattern .. "()" -- INFO "()" makes gmatch return the position of that group
	else
		pattern = "()" .. pattern
	end
	-- `:gmatch` will return all locations in the string where the pattern is
	-- found, the loop looks for the first one that is higher than the offset
	-- to look from
	for pos in strFuncs.gmatch(line, pattern) do
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
function M.getNextPosition(line, offset, key, opts)
	local endOfWord = (key == "ge") or (key == "e")
	local backwards = (key == "b") or (key == "ge")
	local patterns = require("spider.pattern-variants").get(opts, backwards)

	if backwards then
		line = strFuncs.reverse(line)
		endOfWord = not endOfWord

		local isSameLine = offset ~= 0
		if isSameLine then offset = strFuncs.len(line) - offset + 1 end
	end

	-- search for patterns, get closest one
	local matches = {}
	for _, pattern in pairs(patterns) do
		local match = firstMatchAfter(line, pattern, endOfWord, offset)
		if match then table.insert(matches, match) end
	end
	if vim.tbl_isempty(matches) then return nil end -- none found in this line
	local nextPos = math.min(unpack(matches))

	if backwards then nextPos = strFuncs.len(line) - nextPos + 1 end
	return nextPos
end

--------------------------------------------------------------------------------
return M
