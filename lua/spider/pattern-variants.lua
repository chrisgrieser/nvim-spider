local M = {}
--------------------------------------------------------------------------------
---@alias patternList table<string, string>

-- INFO all patterns need to be symmetric to also work for backward motions
-- in case they are asymmetric, they need to be reversed. Currently, this is
-- only the case for the camelCase pattern

---@type patternList
local subwordPatterns = {
	camelCaseWordForward = "%u?[%l]+",
	camelCaseWordBackward = "[%l%d]+%u?",
	ALL_UPPER_CASE_WORD = "%f[%w][%u]+%f[^%w]",
	number = "%d+", -- see issue #31
}

---@type patternList
local skipPunctuationPatterns = {
	-- requires all these variations since lua patterns have no `\b` anchor
	punctuationSurroundedByWhitespace = "%f[^%s]%p+%f[%s]",
	punctuationAtStart = "^%p+%f[%s]",
	punctuationAtEnd = "%f[^%s]%p+$",
	onlyPunctuationLine = "^%p+$",
}

---@type patternList
local fullWordPatterns = {
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
	local punctuationPatterns = opts.skipInsignificantPunctuation and skipPunctuationPatterns
		or allPunctuationPatterns

	local wordPatterns = vim.deepcopy(opts.subwordMovement and subwordPatterns or fullWordPatterns)
	if backwards then wordPatterns.camelCaseWordForward = nil end
	if not backwards then wordPatterns.camelCaseWordBackward = nil end

	local patternsToUse = vim.tbl_extend("force", wordPatterns, punctuationPatterns)
	return patternsToUse
end

--------------------------------------------------------------------------------
return M
