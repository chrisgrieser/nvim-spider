local vim = vim

local Lines = {
	__index = function(tab, k)
		local line = vim.api.nvim_buf_get_lines(0, k - 1, k, true)[1]
		rawset(tab, k, line)
		return line
	end,
}
local Context = {
	__index = function(tab, k)
		if k == "__virtualedit" then
			local v = vim.split(vim.api.nvim_get_option_value("virtualedit", {}), ",", { plain = true })
			rawset(tab, k, v)
			return v
		elseif k == "virtualedit" then
			local ve = tab.__virtualedit

			local c = false
			for _, v in ipairs(ve) do
				if v == "all" or v == "onemore" then
					c = true
					break
				end
			end

			rawset(tab, k, c)
			return c
		elseif k == "blockwise_virtualedit" then
			local ve = tab.__virtualedit

			local c = false
			for _, v in ipairs(ve) do
				if v == "all" or v == "onemore" or v == "block" then
					c = true
					break
				end
			end

			rawset(tab, k, c)
			return c
		elseif k == "selection" then
			local v = vim.api.nvim_get_option_value("selection", {})
			rawset(tab, k, v)
			return v
		end
	end,
}

local M = {}

--- @return table
function M.createContext()
	return setmetatable({
		lines = setmetatable({}, Lines),
		linesCount = vim.api.nvim_buf_line_count(0),
	}, Context)
end

--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param mode nil | "v" | "V" | "" Visual mode, default "v"
function M.visualStart(p1, p2, mode)
	if not mode then
		mode = "v"
	else
		assert(mode == "v" or mode == "V" or mode == "")
	end
	-- Enter visual first! Positions might be valid only in visual
	vim.cmd([[noautocmd normal! ]] .. mode)
	vim.api.nvim_win_set_cursor(0, p1)
	vim.cmd([[noautocmd normal! o]])
	vim.api.nvim_win_set_cursor(0, p2)
end

--- Modifies given position to be clamped to the buffer and line length.
---
--- @param pos table<integer, integer>
--- @param context table Context from `createContext()`
--- @return table<integer, integer>: `pos`
function M.clampPos(pos, context)
	local linesCount = context.linesCount

	if pos[1] < 1 then
		pos[1] = 1
		pos[2] = 0
	elseif pos[1] > linesCount then
		pos[1] = linesCount
		pos[2] = #context.lines[linesCount]
	elseif pos[2] < 0 then
		pos[2] = 0
	else
		pos[2] = math.min(pos[2], #context.lines[pos[1]])
	end

	return pos
end

--- Checks whether `a` < `b`.
--- @param a table<integer, integer>
--- @param b table<integer, integer>
--- @return boolean
function M.posLt(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end

--- Checks whether positions `a` and `b` are equal.
--- @param a table<integer, integer>
--- @param b table<integer, integer>
--- @return boolean
function M.posEq(a, b) return a[1] == b[1] and a[2] == b[2] end

--- Checks whether given 2 positions are on the same character.
--- Positions are (1, 0) indexed, clamped.
---
--- @param p1 table<integer, integer>
--- @param p2 table<integer, integer>
--- @param context table Context from `createContext()`
--- @return boolean
function M.isSameChar(p1, p2, context)
	if p1[1] ~= p2[1] then return false end
	if p1[2] == p2[2] then return true end
	local line = context.lines[p1[1]]
	return vim.fn.charidx(line, p1[2]) == vim.fn.charidx(line, p2[2])
end

--- Modifies `pos` to point to the first byte of the character that contains it.
--- Composing characters are considered a part of one character.
---
--- @param pos table<integer, integer> (1, 0) indexed clamped position
--- @param context table Context from `createContext()`
--- @return table<integer, integer>: `pos`
function M.moveToCur(pos, context)
	local lines = context.lines
	local line = lines[pos[1]]

	local ci = vim.fn.charidx(line, pos[2])
	if ci < 0 then
		pos[2] = #line
	else
		local bi = vim.fn.byteidx(line, ci)
		assert(bi >= 0)
		pos[2] = bi
	end

	return pos
end

--- Modifies `pos` to point to the first byte of the next character.
--- Composing characters are considered a part of one character.
---
--- @param pos table<integer, integer> (1, 0) indexed clamped position
--- @param context table Context from `createContext()`
--- @return table<integer, integer>: `pos`
function M.moveToNext(pos, context)
	local lines = context.lines
	local linesCount = context.linesCount
	local line = lines[pos[1]]

	if pos[2] == #line then
		if pos[1] < linesCount then
			pos[1] = pos[1] + 1
			pos[2] = 0
		end
		return pos
	end

	local ci = vim.fn.charidx(line, pos[2])
	assert(ci >= 0)

	local bi = vim.fn.byteidx(line, ci + 1)
	assert(bi >= 0)
	pos[2] = bi
	return pos
end

--- Modifies `pos` to point to the first byte of the previous character.
--- Composing characters are considered a part of one character.
---
--- @param pos table<integer, integer> (1, 0) indexed clamped position
--- @param context table Context from `createContext()`
--- @return table<integer, integer>: `pos`
function M.moveToPrev(pos, context)
	local lines = context.lines
	local line = lines[pos[1]]

	-- So many cases just bc charidx(line, #line) is not #chars in line...
	-- Even though corresponding is true for byteidx...
	if #line == 0 then
		if pos[1] > 1 then
			pos[1] = pos[1] - 1
			pos[2] = #lines[pos[1]]
		end
		return pos
	elseif pos[2] == #line then
		local ci = vim.fn.charidx(line, #line - 1)
		assert(ci >= 0)
		local bi = vim.fn.byteidx(line, ci)
		assert(bi >= 0)
		pos[2] = bi
		return pos
	end

	local ci = vim.fn.charidx(line, pos[2])
	assert(ci >= 0)
	if ci == 0 then
		if pos[1] > 1 then
			pos[1] = pos[1] - 1
			pos[2] = #lines[pos[1]]
		end
	else
		local bi = vim.fn.byteidx(line, ci - 1)
		assert(bi >= 0)
		pos[2] = bi
	end

	return pos
end

return M
