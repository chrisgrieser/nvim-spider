local M = {
	stringFuncs = {},
}
--------------------------------------------------------------------------------

local originalLuaStringFuncs = {
	reverse = string.reverse,
	find = string.find,
	gmatch = string.gmatch,
	len = string.len,
	initPos = function(_, col)
		col = col + 1 -- from 0-based indexing to 1-based
		local startCol = col
		return col, startCol
	end,
	offset = function(_, pos) return pos end,
}

local luaUtf8Installed, utf8 = pcall(require, "lua-utf8")
if not luaUtf8Installed then
	M.stringFuncs = originalLuaStringFuncs
else
	for name, _ in pairs(originalLuaStringFuncs) do
		if utf8[name] then M.stringFuncs[name] = utf8[name] end
	end
	M.stringFuncs.initPos = function(s, col)
		local offset = 1
		for p, _ in utf8.codes(s) do
			if p > col then break end
			offset = offset + 1
		end
		local startOffset = offset
		return offset, startOffset
	end
end

--------------------------------------------------------------------------------
return M
