--- Common facilities for extending state objects.

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
local pairs = pairs

-- Modules --
local adaptive = require("tektite_core.table.adaptive")

-- Exports --
local M = {}

--
--
--

local function PopulateProperties (from, to)
	if from then
		to = to or {}

		for vtype, list in pairs(from) do
			for k in adaptive.IterSet(list) do
				to[vtype] = adaptive.AddToSet(to[vtype], k)
			end
		end
	end

	return to
end

--- DOCME
function M.NewTag (how, events, actions, sources, targets, to_exclude, ...) -- N.B. will break if events is not a singleton
	local w1, w2, w3, w4

	if how == "extend" then
		w1, w2, w3, w4 = ...
	elseif how then
		w3, w4 = ...
	else
		return events, actions, sources, targets
	end

	if w1 then
		if adaptive.InSet(w1, to_exclude) then
			events = nil
		end

		for k in adaptive.IterSet(w1) do
			if k ~= to_exclude then
				events = adaptive.AddToSet(events, k)
			end
		end
	end

	for k in adaptive.IterSet(w2) do
		actions = adaptive.AddToSet(actions, k)
	end

	return events, actions, PopulateProperties(w3, sources), PopulateProperties(w4, nil)
end

--- DOCME
function M.PrepLinkHelper (prep_link_base, command)
	local funcs, cfuncs = {}

	local function prep_link_ex (object, other, osub, other_sub, links)
		if not funcs[object.type](object, other, osub, other_sub, links) then
			prep_link_base(object, other, osub, other_sub, links)
		end
	end

	return function(object_type, event, arg1, arg2)
		local prep = funcs[object_type]

		if prep then
			return prep, cfuncs and cfuncs[object_type]
		else
			local func, cleanup, how = event(command, prep_link_base, arg1, arg2)

			if (how or cleanup) == "complete" then -- allow optional cleanup as well
				return func, cleanup ~= "complete" and cleanup
			elseif func then
				funcs[object_type] = func

				if cleanup then
					cfuncs = cfuncs or {}
					cfuncs[object_type] = cleanup
				end

				return prep_link_ex, cleanup
			else
				return prep_link_base
			end
		end
	end, prep_link_ex
end

return M