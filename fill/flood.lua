--- Flood-type space-filling operations.

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
local floor = math.floor
local remove = table.remove

-- Modules --
local grid = require("tektite_core.array.grid")
local match_slot_id = require("tektite_core.array.match_slot_id")
local powers_of_2 = require("bitwise_ops.powers_of_2")

-- Exports --
local M = {}

-- --
local Funcs = {
	-- Left --
	function(x, y, xoff, yoff, xmax)
		local index = grid.CellToIndex(x - 1, y, xmax)

		if xoff > 0 then
			return index
		elseif if x > 1 then
			return index, -1, 2^(4 + yoff), 2^(8 + yoff)
		end
	end,

	-- Right --
	function(x, y, xoff, yoff, xmax)
		local index = grid.CellToIndex(x + 1, y, xmax)

		if xoff < 3 then
			return index
		elseif x < xmax then
			return index, 1, 2^(8 + yoff), 2^(4 + yoff)
		end
	end,

	-- Up --
	function(x, y, xoff, yoff, xmax)
		local index = grid.CellToIndex(x, y - 1, xmax)

		if yoff > 0 then
			return index
		elseif y > 1 then
			return index, -.25 * xmax, 2^xoff, 2^(12 + xoff)
		end
	end,

	-- Down --
	function(x, y, xoff, yoff, xmax, ymax)
		local index = grid.CellToIndex(x, y + 1, xmax)

		if yoff < 3 then
			return index
		elseif y < ymax then
			return index, .25 * xmax, 2^(12 + xoff), 2^xoff
		end
	end
}

-- --
local Cells, Nx

-- --
local Closest, CX, CY

--- DOCME
function M.Add (col, row, cell)
	cell.fill.effect = "filter.filler.grid4x4"

	local dist_sq = (col - CX)^2 + (row - CY)^2

	if dist_sq < Closest then
		--
	end

	Cells[grid.CellToIndex(col, row, Nx)] = cell
end

-- --
local Arrays = {}

--- DOCME
function M.Prepare (nx, ny)
	Cells = remove(Arrays) or {}

	for i = 1, nx * ny do
		Cells[i] = false
	end

	Nx, Closest, CX, CY = nx, 1 / 0, floor(nx / 2), floor(ny / 2)
end

--- DOCME
function M.Run ()
	local work, idle = remove(Arrays) or {}, remove(Arrays) or {}

	-- Find "center"?
end

--[[
timer.performWithDelay(100, coroutine.wrap(function(e)
	--
	local cw, ch = display.contentWidth, display.contentHeight

	local cells = {}

	local nx, ny = math.ceil(cw / SpriteDim), math.ceil(ch / SpriteDim) -- use TileW, TileH, and... contentBounds?
	local xmax, ymax = nx * CellCount, ny * CellCount
	local xx, yy = math.floor(xmax / 2), math.floor(ymax / 2)

	local work, idle, used = {}, {}, {} -- Just keep a cache? match_id_slot on used?
	local i1 = grid.CellToIndex(xx, yy, xmax) -- better idea: choose middle-most of regions, then center of that

	work[#work + 1], used[i1] = i1, true

	--
	local max, random, ipairs = math.max, math.random, ipairs

	while true do -- TODO: Make this a boring old timer
		local nwork, nidle = #work, #idle

		for _ = 1, 35 do -- NumIterations
			--
			local to_process = random(40, 50) -- NumToProcess

			if nwork < to_process then
				for _ = nidle, max(1, nidle - to_process), -1 do
					local index = random(nidle)

					nwork, work[nwork + 1] = nwork + 1, s2[index]
					idle[index] = idle[nidle]
					nidle, idle[nidle] = nidle - 1
				end
			end

			--
			for _ = nwork, max(1, nwork - to_process), -1 do
				--
				local index = random(nwork)
				local x, y = grid.IndexToCell(work[index], xmax)
				local xb, yb = floor((x - 1) * .25), floor((y - 1) * .25)
				local xoff, yoff = x - xb * 4 - 1, y - yb * 4 - 1
				local bit = 2^(yoff * 4 + xoff)
				local ci = yb * nx + xb + 1
				local ceffect = cells[ci].fill.effect

				ceffect.bits = ceffect.bits + bit

				--
				for _, func in ipairs(Funcs) do
					local si, delta, nbit_self, nbit_other = func(x, y, xoff, yoff)

					if si then
						if delta then
							local neffect = cells[ci + delta].fill.effect
							local cn, nn = ceffect.neighbors, neffect.neighbors

							if not powers_of_2.IsSet(cn, nbit_self) then
								ceffect.neighbors = cn + nbit_self
							end

							if not powers_of_2.IsSet(nn, nbit_other) then
								neffect.neighbors = nn + nbit_other
							end
						end

						if not used[si] then
							idle[nidle + 1], used[si], nidle = si, true, nidle + 1
						end
					end
				end

				--
				work[index] = work[nwork]
				nwork, work[nwork] = nwork - 1
			end
		end

		coroutine.yield()
	end
end), 0)
]]

-- Export the module.
return M