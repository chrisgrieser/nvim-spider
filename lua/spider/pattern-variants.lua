local M = {}
--------------------------------------------------------------------------------
---@alias patternList table<string, string>

-- INFO All patterns need to be symmetric to also work for backward motions. In
-- case they are asymmetric, they need to be reversed. (Currently, this is only
-- the case for the camelCase pattern.)

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
local fullWord = {
	word = "[%w_]+", -- `_` is usually considered a word character
}

---@type patternList
local anyPunctuation = {
	punctuation = "%p+",
}

---@param var any
---@return boolean
local function isStringArray(var)
	if type(var) ~= "table" then return false end
	for _, value in ipairs(var) do
		if type(value) ~= "string" then return false end
	end
	return true
end

--------------------------------------------------------------------------------

---@param opts Spider.config
---@param backwards boolean
---@return patternList
---@nodiscard
function M.get(opts, backwards)
	-- user set custom pattern that will override spider's default patterns
	local customPat = opts.customPatterns
	if customPat and isStringArray(customPat) and #customPat > 0 then return customPat end
	if customPat.patterns and #customPat.patterns > 0 and customPat.overrideDefault then
		return customPat.patterns
	end

	-- spider's default patterns, depending on user settings
	local punctuationPatterns = opts.skipInsignificantPunctuation and skipPunctuationPatterns
		or anyPunctuation

	local wordPatterns = vim.deepcopy(opts.subwordMovement and subwordPatterns or fullWord)
	if backwards then wordPatterns.camelCaseWordForward = nil end
	if not backwards then wordPatterns.camelCaseWordBackward = nil end

	-- merge user patterns with spider's default patterns
	local patternsToUse =
		vim.tbl_extend("force", wordPatterns, punctuationPatterns, customPat.patterns or {})
	return patternsToUse
end

--------------------------------------------------------------------------------
return M
