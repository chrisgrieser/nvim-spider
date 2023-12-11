local M = {}
--------------------------------------------------------------------------------
-- INFO `%f[set]` is used to emulate `#b`

---@alias patternList table<string, string>

---@type patternList
local subwordPatterns = {
	camelCaseWord = "%u?[%l]+",
	-- only camelCase needs reversal, since the other patterns are already symmetric
	camelCaseWordReversed = "[%l%d]+%u?",
	ALL_UPPER_CASE = "%f[%w][%u]+%f[^%w]",
	number = "%d+", -- see issue #31
}

---@type patternList
local skipPunctuationPatterns = {
	punctuationSurroundedByWhitespace = "%f[^%s]%p+%f[%s]",
	punctuationAtStart = "^%p+%f[%s]",
	punctuationAtEnd = "%f[^%s]%p+$",
	onlyPunctuationLine = "^%p+$",
}

---@type patternList
local simplePatterns = {
	word = "%w+",
	punctuation = "%p+",
}

--------------------------------------------------------------------------------

---@param opts optsObj configuration table as in setup()
---@return patternList
---@nodiscard
function M.get(opts)
	local patterns = subwordPatterns
	if opts.skipInsignificantPunctuation then
		patterns = vim.tbl_extend("error", patterns, skipPunctuationPatterns)
	else
		patterns.punctuation = simplePatterns.punctuation
	end
	return patterns
end

--------------------------------------------------------------------------------
return M
