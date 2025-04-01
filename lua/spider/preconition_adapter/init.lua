local M = {}

--- Exposes Precognition Spider Motions Adapter
---@return Precognition.MotionsAdapter
function M.expose_adapter()
	local globalOpts = require("spider.config").globalOpts
	if not globalOpts.precognitionIntegrationEnabled then return {} end
	local ok, vanilla_motions = pcall(require, "precognition.motions.vanilla_motions")
	if not ok then
		vim.api.nvim_echo({ { "[Spider] `precognition` not found" } }, true, { err = true })
		return {}
	end
	local spider = require("spider.motion-logic")
	return {
		next_word_boundary = function(str, cursorcol, linelen, big_word)
			if big_word then
				return vanilla_motions.next_word_boundary(str, cursorcol, linelen, big_word)
			end
			return spider.getNextPosition(str, cursorcol, "w", globalOpts) or 0
		end,
		end_of_word = function(str, cursorcol, linelen, big_word)
			if big_word then return vanilla_motions.end_of_word(str, cursorcol, linelen, big_word) end
			return spider.getNextPosition(str, cursorcol, "e", globalOpts) or 0
		end,
		prev_word_boundary = function(str, cursorcol, linelen, big_word)
			if big_word then
				return vanilla_motions.prev_word_boundary(str, cursorcol, linelen, big_word)
			end
			return spider.getNextPosition(str, cursorcol, "b", globalOpts) or 0
		end,
	}
end

return M
