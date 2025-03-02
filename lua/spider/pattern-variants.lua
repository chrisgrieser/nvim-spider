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

---@param table table table to verify.
---@return boolean
local function isStringArray(table)
	if type(table) ~= "table" then return false end

	for _, value in ipairs(table) do
		if type(value) ~= "string" then return false end
	end

	return true
end

--------------------------------------------------------------------------------

---@param opts Spider.config configuration table as in setup()
---@param backwards boolean whether to adjust patterns for backward motions
---@return patternList
---@nodiscard
function M.get(opts, backwards)
	-- opts.customPatterns.overrideDefault will default to true if it is not passed in.
	-- This preserves the original behavior of spider.
	-- Users can set overrideDefault to true, but spider will behave the same as the original behavior.
	-- Behavior will change if a user sets the overrideDefault key to true within a customPatterns.patterns table.
	-- any custom patterns take precedence

	-- need to check if opts.customPatterns is a string array to avoid breaking changes.
	if opts.customPatterns and isStringArray(opts.customPatterns) then
		if #opts.customPatterns > 0 then return opts.customPatterns end
	end

	-- this checks if a user set a custom pattern in the patterns table
	-- then it checks if overrideDefault was set
	if opts.customPatterns.patterns and #opts.customPatterns.patterns > 0 then
		if opts.customPatterns.overrideDefault then return opts.customPatterns.patterns end
	end

	local punctuationPatterns = opts.skipInsignificantPunctuation and skipPunctuationPatterns
		or allPunctuationPatterns

	local wordPatterns = vim.deepcopy(opts.subwordMovement and subwordPatterns or fullWordPatterns)
	if backwards then wordPatterns.camelCaseWordForward = nil end
	if not backwards then wordPatterns.camelCaseWordBackward = nil end

	-- user patterns default to {}
	-- user patterns table only changes patterntsToUse if patterns has a pattern and overrideDefaults was set to false.
	local patternsToUse =
		vim.tbl_extend("force", wordPatterns, punctuationPatterns, opts.customPatterns.patterns)
	return patternsToUse
end

--------------------------------------------------------------------------------
return M
