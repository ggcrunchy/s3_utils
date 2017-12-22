--- Value store used by some actions and values.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local assert = assert
local pairs = pairs

-- Modules --
local object_vars = require("config.ObjectVariables")

-- Exports --
local M = {}

--
--
--

local Vars = {}

for _, family in ipairs(object_vars.families) do
	Vars[family] = {}
end

-- --
local CustomFamilies = {}

--- DOCME
function M.GetVariable (family, vtype, name)
	local fset = Vars[family] or CustomFamilies[family]
	local vars = fset and fset[vtype]

	return vars and vars[name]
end

--- DOCME
function M.RemoveFamily (family)
	if CustomFamilies[family] then -- ignore nil
		CustomFamilies[family] = nil
	end
end

--- DOCME
function M.SetVariable (family, vtype, name, value)
	assert(object_vars.properties[vtype], "Unknown variable type")

	if family ~= nil then
		local fset = Vars[family] or CustomFamilies[family]

		if not fset then
			fset = {}
			CustomFamilies[family] = fset
		end

		local vars = fset[vtype] or {}

		fset[vtype], vars[name] = vars, value
	end
end

--- DOCME
function M.Visit (family, func)
	local fset = Vars[family] or CustomFamilies[family]

	if fset then
		for vtype, vars in pairs(fset) do
			func("type", vtype)

			for name, value in pairs(vars) do
				func("var", name, value) 
			end
		end

		return true
	else
		return false
	end
end

-- Export the module.
return M