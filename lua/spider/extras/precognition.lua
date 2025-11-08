local M = {}
--- Register Precognition Spider Motions Adapter
M.register_adapter = function()
	local globalOpts = require("spider.config").globalOpts
	local ok, vanillaMotions = pcall(require, "precognition.motions.vanilla_motions")
	if not ok then return end
	local spider = require("spider.motion-logic")
	local adapter = {
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
	require("precognition.motions").register_motions(adapter)
end

return M
