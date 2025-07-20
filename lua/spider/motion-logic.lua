local M = {}
local strFuncs = require("spider.extras.utf8-support").stringFuncs
--------------------------------------------------------------------------------

-- This method is necessary as opposed to a simple `:find` to correctly
-- determine a word the cursor is already standing on.
---@param line string
---@param pattern string
---@param endOfWord boolean look for the end of the pattern instead of the start
---@param searchOffset number look for the first match after this number
---@nodiscard
---@return number|false matchPos false if no match was found
local function getMatchpos(line, pattern, endOfWord, searchOffset)
	-- special case: pattern with unescaped ^/$, since there can only be one
	-- match and since gmatch won't work with them

	-- trailing $ could be escaped $, see #63
	local endsWithUnescapedDollar = vim.endswith(pattern, "$") and not vim.endswith(pattern, "%$")
	if vim.startswith(pattern, "^") or endsWithUnescapedDollar then
		-- checking for high col count for virtualedit
		if endsWithUnescapedDollar and searchOffset > strFuncs.len(line) then return false end
		if vim.startswith(pattern, "^") and searchOffset ~= 0 then return false end

		local startPos, endPos = strFuncs.find(line, pattern)
		if not startPos or not endPos then return false end

		local matchPos = endOfWord and endPos or startPos
		if matchPos > searchOffset then return matchPos end
		return false
	end

	-----------------------------------------------------------------------------

	-- `()` makes gmatch return the position of that group
	pattern = endOfWord and (pattern .. "()") or ("()" .. pattern)

	-- `:gmatch` will return all locations in the string where the pattern is
	-- found, the loop looks for the first one that is higher than the offset
	-- to look from
	for matchPos in strFuncs.gmatch(line, pattern) do
		if type(matchPos) == "string" then return false end

		if endOfWord then matchPos = matchPos - 1 end
		if matchPos > searchOffset then return matchPos end
	end
	return false
end

---@param line string input string where to find the pattern
---@param searchOffset number position to start looking from
---@param key "w"|"e"|"b"|"ge" the motion to perform
---@param opts Spider.config
---@nodiscard
---@return number|false nextPos false if pattern was not found
function M.getNextPosition(line, searchOffset, key, opts)
	local endOfWord = (key == "ge") or (key == "e")
	local backwards = (key == "b") or (key == "ge")
	local patterns = require("spider.pattern-variants").get(opts, backwards)

	if backwards then
		line = strFuncs.reverse(line)
		endOfWord = not endOfWord

		local isSameLine = searchOffset ~= 0
		if isSameLine then searchOffset = strFuncs.len(line) - searchOffset + 1 end
	end

	-- search for patterns, get closest one
	local matches = {}
	for _, pattern in pairs(patterns) do
		local matchPos = getMatchpos(line, pattern, endOfWord, searchOffset)
		if matchPos then table.insert(matches, matchPos) end
	end
	if #matches == 0 then return false end -- none found in this line
	local nextPos = math.min(unpack(matches))

	if backwards then nextPos = strFuncs.len(line) - nextPos + 1 end
	return nextPos
end

--------------------------------------------------------------------------------
return M
