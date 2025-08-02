-- based on https://github.com/vanaigr/motion.nvim at 5511dd91ff4cc51fceca4afdab92705ca9442c55

local vim = vim

local u = require("spider.extras.operator-pending.util")

local M = {}

M.util = u

--- Modifies endpoints from range [`p1`, `p2`) or [`p2`, `p1`)
--- for charwise visual selection. Positions are (1, 0) indexed.
---
--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param context table? Context from `createContext()`
--- @return boolean: Whether the selection can be created.
function M.rangeToVisual(p1, p2, context)
	if not context then context = u.createContext() end
	local lines = context.lines
	local linesCount = context.linesCount

	u.clampPos(p1, context)
	u.clampPos(p2, context)

	local sel = context.selection
	if sel == "exclusive" then return not u.isSameChar(p1, p2, context) end

	local posF, posL
	if u.posLt(p1, p2) then
		posF, posL = p1, p2
	else
		posF, posL = p2, p1
	end

	u.moveToCur(posF, context)
	u.moveToPrev(posL, context)

	-- Note: old + virtualedit ~= inclusive  (if old and ends in EOL, it is ignored)
	if sel == "inclusive" or (sel == "old" and context.virtualedit) then
		return not u.posLt(posL, posF)
	end

	assert(sel == "old")

	if posF[2] > 0 and posF[2] >= #lines[posF[1]] then
		if posF[1] >= linesCount then return false end
		posF[1] = posF[1] + 1
		posF[2] = 0
	end

	if posL[2] > 0 and posL[2] >= #lines[posL[1]] then posL[2] = #lines[posL[1]] - 1 end

	return not u.posLt(posL, posF)
end

--- Modifies endpoints from range [`p1`, `p2`] or [`p2`, `p1`]
--- for charwise visual selection. Positions are (1, 0) indexed.
---
--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param context table? Context from `createContext()`
---
--- @return boolean: Whether the selection can be created.
function M.rangeInclusiveToVisual(p1, p2, context)
	if not context then context = u.createContext() end
	local lines = context.lines
	local linesCount = context.linesCount

	u.clampPos(p1, context)
	u.clampPos(p2, context)

	local sel = context.selection
	if sel == "inclusive" or (sel == "old" and context.virtualedit) then return true end

	local posF, posL
	if u.posLt(p1, p2) then
		posF, posL = p1, p2
	else
		posF, posL = p2, p1
	end

	if sel == "exclusive" then
		u.moveToNext(posL, context)
		return true
	end

	assert(sel == "old")

	if posF[2] > 0 and posF[2] >= #lines[posF[1]] then
		if posF[1] >= linesCount then return false end -- last EOL in file
		posF[1] = posF[1] + 1
		posF[2] = 0
	end

	if posL[2] > 0 and posL[2] >= #lines[posL[1]] then posL[2] = #lines[posL[1]] - 1 end

	return not u.posLt(posL, posF)
end

--- Modifies endpoints `p1` and `p2` from range for a text object. Positions are (1, 0) indexed.
---
--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param opts { mode: "v" | "V" | "", inclusive: boolean, context: table }
---
--- @return string | nil: which visual mode to use when setting selection. nil if not possible to select
function M.calcEndpoints(p1, p2, opts)
	local mode = opts.mode
	local incl = opts.inclusive
	local context = opts.context
	if mode == "v" then
		if incl then
			if M.rangeInclusiveToVisual(p1, p2, context) then return "v" end
		else
			if M.rangeToVisual(p1, p2, context) then return "v" end
		end
	elseif mode == "V" then
		u.clampPos(p1, context)
		u.clampPos(p2, context)
		return "V"
	else
		assert(mode == "")

		u.clampPos(p1, context)
		u.clampPos(p2, context)

		local sel = context.selection
		if incl then
			if sel == "inclusive" or (sel == "old" and context.blockwiseVirtualedit) then
				return ""
			elseif sel == "old" then
				local lines = context.lines
				if (p1[2] == 0 or p1[2] < #lines[p1[1]]) and (p2[2] == 0 or p2[2] < #lines[p2[1]]) then
					return ""
				end
			end
		else
			if sel == "exclusive" then
				if not u.isSameChar(p1, p2, context) then return "" end
			end
		end
	end
end

--- Sets the range defined by `p1` and `p2` as positions for a custom text object.
--- (Default: charwise end-exclusive). `inclusive` only affects the column value,
--- and only in charwise and blockwise modes. Handles forced motion.
--- Positions are (1, 0) indexed, both are modified.
---
--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param opts { mode: nil | "v" | "V" | "", inclusive: boolean?, context: table? }?
--- @return boolean: False if couldn't set the positions.
function M.setEndpoints(p1, p2, opts)
	local context = opts and opts.context or u.createContext()

	local curMode = vim.fn.mode(true)

	-- note: forced motion doesn't affect text objects defined through
	-- visual selection (apart from broken <C-V>). Handle it ourselves.
	local mode = opts and opts.mode or "v"
	local inclusive = opts and opts.inclusive and true or false
	if curMode == "nov" then
		if mode == "v" then inclusive = not inclusive end
		mode = "v"
	elseif curMode == "noV" then
		mode = "V"
	elseif curMode == "no" then
		mode = ""
	end

	local resMode = M.calcEndpoints(p1, p2, {
		mode = mode,
		inclusive = inclusive,
		context = context,
	})
	if not resMode then return false end

	u.visualStart(p1, p2, resMode)
	return true
end

return M
