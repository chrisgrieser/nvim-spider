local M = {}
--------------------------------------------------------------------------------

---@class Spider.config.customPatterns
---@field patterns string[]? string array of lua patterns to match against.
---@field overrideDefault boolean? set to false to extend the default patterns with customPatterns. Defaults to true.

---@class Spider.config
local defaultOpts = {
	skipInsignificantPunctuation = true,
	consistentOperatorPending = false,
	subwordMovement = true,
	---@type Spider.config.customPatterns
	customPatterns = {
		patterns = {},
		overrideDefault = true,
	},
}

--------------------------------------------------------------------------------

M.globalOpts = defaultOpts

---@param userOpts? Spider.config
function M.setup(userOpts) M.globalOpts = vim.tbl_deep_extend("force", defaultOpts, userOpts or {}) end

--------------------------------------------------------------------------------
return M
