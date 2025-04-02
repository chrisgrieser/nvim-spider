--- Exposes Precognition Spider Motions Adapter
---@diagnostic disable-next-line: undefined-doc-name
---@return Precognition.MotionsAdapter
function init()
	local globalOpts = require("spider.config").globalOpts
	local ok, vanillaMotions = pcall(require, "precognition.motions.vanilla_motions")
	if not ok then
		vim.api.nvim_echo({ { "[Spider] `precognition` not found" } }, true, { err = false })
		return {}
	end
	local spider = require("spider.motion-logic")
	return {
		next_word_boundary = function(str, cursorcol, linelen, bigWord)
			if bigWord then return vanillaMotions.next_word_boundary(str, cursorcol, linelen, bigWord) end
			return spider.getNextPosition(str, cursorcol, "w", globalOpts) or 0
		end,
		end_of_word = function(str, cursorcol, linelen, bigWord)
			if bigWord then return vanillaMotions.end_of_word(str, cursorcol, linelen, bigWord) end
			return spider.getNextPosition(str, cursorcol, "e", globalOpts) or 0
		end,
		prev_word_boundary = function(str, cursorcol, linelen, bigWord)
			if bigWord then return vanillaMotions.prev_word_boundary(str, cursorcol, linelen, bigWord) end
			return spider.getNextPosition(str, cursorcol, "b", globalOpts) or 0
		end,
		-- precognition.nvim currently does not support multi character motions (see https://github.com/tris203/precognition.nvim/issues/101#issuecomment-2676676721)
	}
end
-- --- Exposes Precognition Spider Motions Adapter
-- ---@return Precognition.MotionsAdapter
-- function M.expose_adapter()
-- end
local M = init()
return M
