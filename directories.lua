--- Utilities to resolve directories and manage paths, for both modules and resources.

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
local error = error
local getmetatable = getmetatable
local newproxy = newproxy
local pcall = pcall
local require = require
local setmetatable = setmetatable
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local strings = require("tektite_core.var.strings")

-- Cached module references --
local _LazyRequire_

-- Exports --
local M = {}

--
--
--

local LabelToNames = {}

--- DOCME
function M.AddUnderLabel (label, name)
	LabelToNames[label] = adaptive.Append(LabelToNames[label], name)
end

--
--
--

local Paths = {}

--- DOCME
function M.GetNamedPath (name)
	return Paths[name]
end

--
--
--

--- DOCME
function M.IterateForLabel (label)
	return adaptive.IterArray(LabelToNames[label])
end

--
--
--

local ProxyToInfo = setmetatable({}, { __mode = "k" })

local function GetModule (proxy)
	local info = ProxyToInfo[proxy]

	if not info.module then
		info.module = require(info.name)
	end

	return info.module
end

local ProxyProto = newproxy(true)

local ProxyProtoMT = getmetatable(ProxyProto)

function ProxyProtoMT:__call (...)
	return GetModule(self)(...)
end

function ProxyProtoMT:__index (k)
	return GetModule(self)[k]
end

--- Utility to mitigate circular module requirements. Provided module access is not needed
-- immediately&mdash;in particular, it can wait until the requiring module loads&mdash;the
-- returned proxy may be treated largely as a normal module.
-- @string name Module name, as passed to @{require}.
-- @treturn table Module proxy, to be accessed like the module proper.
function M.LazyRequire (name)
	local proxy = newproxy(ProxyProto)

	ProxyToInfo[proxy] = { name = name }

	return proxy
end

--
--
--

local function AddSlash (str)
	return strings.EndsWith(str, "/") and str or str .. "/"
end

--- DOCME
function M.FromModule (mod, relative)
	mod = strings.RemoveLastSubstring(mod or "", "%.", "/")

	if #mod > 0 then
		mod = AddSlash(mod)
	end

	if relative then
		mod = AddSlash(mod .. relative)
	end

	return mod
end

--
--
--

--- DOCME
function M.SetNamedPath (name, path)
	Paths[name] = path
end

--
--
--

local _, NotFoundErr = pcall(require, "%s") -- assumes Lua error like "module 'name' not found: etc", e.g.
											-- as in https://www.lua.org/source/5.1/loadlib.c.html#ll_require
local _, last = NotFoundErr:find("not found:")

NotFoundErr = NotFoundErr:sub(1, last - 1)

--- DOCME
function M.TryRequire (path, opts)
	local cache = opts and opts.absence_cache

	if not (cache and cache[path]) then
		local rfunc = (opts and opts.lazy) and _LazyRequire_ or require
		local ok, res = pcall(rfunc, path)

		if ok then
			return res
		elseif type(res) ~= "string" or not res:starts(NotFoundErr:format(path)) then -- ignore "not found" errors...
			error(res)
		elseif cache then
			cache[path] = false
		end
	end

	return nil
end

--
--
--

_LazyRequire_ = M.LazyRequire

return M