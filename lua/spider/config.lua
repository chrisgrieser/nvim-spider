local M = {}
--------------------------------------------------------------------------------

---@class Spider.config
local defaultOpts = {
	skipInsignificantPunctuation = true,
	consistentOperatorPending = false,
	subwordMovement = true,
	customPatterns = {
		patterns = {}, ---@type string[]
		overrideDefault = true,
	},
}

M.globalOpts = defaultOpts

---@param userOpts? Spider.config
function M.setup(userOpts) M.globalOpts = vim.tbl_deep_extend("force", defaultOpts, userOpts or {}) end

--------------------------------------------------------------------------------
return M
