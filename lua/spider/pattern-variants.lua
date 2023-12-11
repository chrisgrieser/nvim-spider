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
local fullwordPatterns = {
	word = "%w+",
}

---@type patternList
local allPunctuationPatterns = {
	punctuation = "%p+",
}

--------------------------------------------------------------------------------

---@param opts optsObj configuration table as in setup()
---@param backwards boolean whether to adjust patterns for backward motions
---@return patternList
---@nodiscard
function M.get(opts, backwards)
	local punctuationPatterns = opts.skipInsignificantPunctuation
		and skipPunctuationPatterns or allPunctuationPatterns
	local wordPatterns = opts.subwordMovement and subwordPatterns or fullwordPatterns

	if opts.subwordMovement and backwards then
		wordPatterns.camelCaseWord = wordPatterns.camelCaseWordReversed
	end

	local patternsToUse = vim.tbl_extend("force", wordPatterns, punctuationPatterns)
	return patternsToUse
end

--------------------------------------------------------------------------------
return M
