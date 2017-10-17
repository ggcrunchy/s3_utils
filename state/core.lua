--- Core routines of state system.

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
local select = select

-- Exports --
local M = {}

-- Figure out the VarFamily tiers...
-- ...policies for persistence, rollback, etc...
-- ...variable substitution, gensyms, object referents (last mostly solved thanks to property redesign... others still relevant?)
-- Random number generators, time facilities?

-- --
local FuncTypes = {}

--- DOCME
-- @string type
-- @string name
-- @uint arity
-- @callable func
function M.AddFunction (type, name, arity, func)
	local funcs = assert(FuncTypes[type], "Unknown type")
	local afuncs = funcs[arity] or {}

	funcs[arity], afuncs[name] = afuncs, func
end

--- DOCME
-- @string type
-- @callable fixup
function M.AddType (type, fixup)
	assert(not FuncTypes[type], "Type already exists")

	FuncTypes[type] = { fixup = fixup }
end

--- DOCME
-- @string type
-- @string name
-- @uint arity
-- @param ...
-- @return X
function M.CallFunction (type, name, arity, ...)
	local funcs = assert(FuncTypes[type], "Unknown type")
	local afuncs = funcs[arity]
	local func = afuncs and afuncs[name]

	return funcs.fixup(func and func(select(arity, ...)))
end

-- Export the module.
return M