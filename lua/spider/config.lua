local M = {}
--------------------------------------------------------------------------------

---@class customPatterns
---@field patterns string[]? string array of lua patterns to match against.
---@field overrideDefault boolean? set to false to extend the default patterns with customPatterns. Defaults to true.

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
M.globalOpts = defaultOpts

---@param userOpts? optsObj
function M.setup(userOpts) M.globalOpts = vim.tbl_deep_extend("force", defaultOpts, userOpts or {}) end

--------------------------------------------------------------------------------
return M
