local M = {}
--------------------------------------------------------------------------------
---@alias patternList table<string, string>

-- INFO Currently, all patterns need to be symmetric to also work for backward
-- motions. In case they are asymmetric, they need to be reversed. Currently,
-- this is only the case for the camelCase pattern.

---@type patternList
local subwordPatterns = {
	number = "%d+", 
	camelCaseWordForward = "%u?%l+",
	camelCaseWordBackward = "%l+%u?",
	ALL_UPPER_CASE_WORD = "%u%u+",
	-- Since the previous patterns don't match `A_B_C`, we need to match single
	-- uppercase letters. The frontier-pattern is required to avoid matching
	-- camelCase words only with a single letter.
	SINGLE_UPPERCASE_CHAR = "%f[%w][%u]+%f[^%w]",
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
	word = "[%w_]+", -- `_` is usually considered a word character
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
	-- any custom patterns take precedence
	if opts.customPatterns and #opts.customPatterns > 0 then return opts.customPatterns end

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
