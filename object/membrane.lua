--- Membrane operations.

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
local ipairs = ipairs
local remove = table.remove
local sort = table.sort
local sqrt = math.sqrt

-- Modules --
local integrators = require("tektite_core.number.integrators")
local polynomial = require("spline_ops.cubic.polynomial")

-- Exports --
local M = {}

--
--
--

local function DistanceCompare (a, b)
	return a.dist2 > b.dist2
end

local N = 20

local Integrand, Poly = polynomial.LineIntegrand()

local Heap, Stash = {}, {}

--- DOCME
function M.Stretch (mpath, interior, used, x, y, radius, depth)
	if interior and radius > 0 then
		local r2 = radius^2

		for _, index in ipairs(interior) do
			if not used[index] then
				local px, py = mpath:getVertex(index)
				local dist2 = (px - x)^2 + (py - y)^2

				if dist2 <= r2 then
					local entry = remove(Stash) or {}

					entry.index, entry.px, entry.py, entry.dist2, used[index] = index, px, py, dist2, true

					Heap[#Heap + 1] = entry
				end
			end
		end

		if #Heap > 0 then
			local dx, dy = radius, depth
			local ax, ay = 2 * (1 - dx), 2 * dy
			local bx, by = -1.5 * ax, -1.5 * ay

			polynomial.SetFromCoefficients(Poly, ax, ay, bx, by, 1, 0)

			local s, sfrac, t, dt = integrators.Romberg(Integrand, 0, 1), 1 / 0, 1, 1 / N
			local group, ir, sl, sr = {}, 1 / radius

			sort(Heap, DistanceCompare)

			repeat
				local entry = remove(Heap)

				--
				group[#group + 1] = entry.index
				group[#group + 1] = entry.px
				group[#group + 1] = entry.py

				--
				local dist2 = entry.dist2

				if dist2 > 1e-12 then
					local tfrac = 1 - sqrt(dist2) * ir

					while tfrac < sfrac do
						t = t - dt
						sl, sr = integrators.Romberg(Integrand, 0, t), sl or s
						sfrac = sl / s
					end

					local offset = (sfrac - sl) / (sr - sl)
					local scale = 1 - (t + offset * dt)

					-- Reverse
					mpath:setVertex(entry.index, x + scale * (entry.px - x), y + scale * (entry.py - y))
				end

				--
				Stash[#Stash + 1] = entry
			until #Heap == 0

			return group
		end
	end
end

--
--
--

--- DOCME
function M.Release (mpath, indices, used)
	for i = 1, #(indices or ""), 3 do
		local index = indices[i]

		mpath:setVertex(index, indices[i + 1], indices[i + 2])

		used[index] = nil
	end
end

--
--
--

return M