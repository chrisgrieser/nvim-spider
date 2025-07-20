local M = {}

-- PERF avoid importing submodules here, since it results in them all being loaded
-- on initialization instead of lazy-loading them when needed.
--------------------------------------------------------------------------------

---Equivalent to fn.getline(), but using more efficient nvim api.
---@param lnum number
---@nodiscard
---@return string
local function getline(lnum)
	local lineContent = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)
	return lineContent[1]
end

local function normal(keys) vim.cmd.normal { keys, bang = true } end

--------------------------------------------------------------------------------

---@param userOpts? Spider.config
function M.setup(userOpts) require("spider.config").setup(userOpts) end

---@param key "w"|"e"|"b"|"ge" the motion to perform
---@param motionOpts? Spider.config command-specific config table
function M.motion(key, motionOpts)
	local strFuncs = require("spider.extras.utf8-support").stringFuncs
	local globalOpts = require("spider.config").globalOpts
	local opts = vim.tbl_deep_extend("force", globalOpts, motionOpts or {})

	-- GUARD validate motion parameter
	if not (key == "w" or key == "e" or key == "b" or key == "ge") then
		local msg = "Invalid key: " .. key .. "\nOnly `w`, `e`, `b`, and `ge` are supported."
		vim.notify(msg, vim.log.levels.ERROR, { title = "nvim-spider" })
		return
	end

	local startPos = vim.api.nvim_win_get_cursor(0)
	local row, col = unpack(startPos)
	local lastRow = vim.api.nvim_buf_line_count(0)
	local forwards = (key == "w") or (key == "e")

	local line = getline(row)
	local offset, _ = strFuncs.initPos(line, col)

 -- looping through counts
	for _ = 1, vim.v.count1, 1 do
		-- looping through rows (if next location not found in line)
		while true do
			local result = require("spider.motion-logic").getNextPosition(line, offset, key, opts)
			if result then
				offset = result
				break
			end

			offset = 0
			row = forwards and row + 1 or row - 1
			if row > lastRow or row < 1 then return end
			line = getline(row)
		end
	end

	col = strFuncs.offset(line, offset) - 1 -- lua string indices different

	-- operator-pending specific considerations (see issues #3 and #5)
	local mode = vim.api.nvim_get_mode().mode
	local isOpPendingMode = mode:sub(1, 2) == "no" -- [n]ormal & [o]perator, not the word "no"
	if isOpPendingMode then
		if opts.consistentOperatorPending then
			local opPending = require("spider.extras.operator-pending")
			opPending.setEndpoints(startPos, { row, col }, { inclusive = key == "e" })
			return
		end

		if key == "e" then
			offset = offset + 1
			col = strFuncs.offset(line, offset) - 1
		end
		if col == #line then
			-- HACK columns are end-exclusive, cannot actually target the last
			-- character in the line without switching to visual mode
			normal("v")
			offset = offset - 1
			col = strFuncs.offset(line, offset) - 1
		end
	end

	-- respect `opt.foldopen = "hor"`
	local shouldOpenFold = vim.tbl_contains(vim.opt_local.foldopen:get(), "hor")
	if mode == "n" and shouldOpenFold then normal("zv") end

	vim.api.nvim_win_set_cursor(0, { row, col })
end

--------------------------------------------------------------------------------
return M
