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
local ipairs = ipairs
local max = math.max
local random = math.random
local remove = table.remove

-- Modules --
local grid = require("tektite_core.array.grid")
local match_slot_id = require("tektite_core.array.match_slot_id")
local powers_of_2 = require("bitwise_ops.powers_of_2")
local timers = require("corona_utils.timers")

-- Kernels --
require("s3_utils.kernel.grid4x4")

-- Exports --
local M = {}

-- Helpers to look at next unit over --
local Funcs = {
	-- Left --
	function(x, y, xoff, yoff, xmax)
		local index = grid.CellToIndex(x - 1, y, xmax)

		if xoff > 0 then
			return index
		elseif x > 1 then
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

-- Current cells list to populate; horizontal, vertical cell counts --
local Cells, Nx, Ny

-- Current closest squared distance to center cell; center cell coordinates --
local Closest, CX, CY

-- Center cell coordinates (or current closest) --
local MidCol, MidRow

--- Adds (or overwrites) a cell to the effect being prepared.
-- @uint col Column of cell, in [1, _nx_] (cf. @{Prepare})...
-- @uint row ...and row, in [1, _ny_].
-- @pobject cell Display object found in cell, which will comprise a 4x4 grid of units, all
-- of them off by default.
-- @see Run
function M.Add (col, row, cell)
	cell.fill.effect = "filter.filler.grid4x4_neighbors"

	local dist_sq = (col - CX)^2 + (row - CY)^2

	if dist_sq < Closest then
		Closest, MidCol, MidRow = dist_sq, col, row
	end

	Cells[grid.CellToIndex(col, row, Nx)] = cell
end

-- Cache of cell / index arrays --
local Arrays = {}

--- Prepares the effect, allowing cells to be added.
-- @uint nx Number of cells (whether optimized or not), horizontally...
-- @uint ny ...and vertically.
-- @see Add, Run
function M.Prepare (nx, ny)
	-- Grab a cells array.
	Cells = remove(Arrays) or {}

	-- Initially, no cell is occupied.
	for i = 1, nx * ny do
		Cells[i] = false
	end

	-- Save the cell counts. Initialize state used to incrementally find the center cell.
	Nx, Ny, Closest, CX, CY = nx, ny, 1 / 0, floor(.5 * (nx + 1)), floor(.5 * (ny + 1))
end

-- Cache of grid use wrappers --
local Used = {}

--- Runs the effect.
-- @ptable[opt] opts Fill options. Fields:
--
-- * **iters**: Number of times to drive the fill along when the timer fires. For the most
-- part, this is a multiple of **to\_process**, taking into account its randomness.
-- * **to\_process**: Average number of elements to process (if possible) per iteration.
-- * **to\_process\_var**: Maximum number of elements to vary from **to\_process**, on a
-- given iteration.
-- * **on\_done**: If present, called (with the timer handle as argument) if and when the
-- fill has completed.
-- @treturn TimerHandle Timer underlying the effect, which may be canceled.
-- @see Add, Prepare
function M.Run (opts)
	-- Reset the grid-in-use state.
	local used = remove(Used) or match_slot_id.Wrap{}

	used("begin_generation")

	-- Save the cells reference, freeing up the module variable. Grab work and idle arrays.
	local cells, work, idle = Cells, remove(Arrays) or {}, remove(Arrays) or {}

	Cells = nil

	-- Set up some parameters.
	local niters = opts and opts.iters or 5
	local nprocess = opts and opts.to_process or 13
	local nvar = opts and opts.to_process_var or 5
	local nlow, nhigh = nprocess - nvar, nprocess + nvar
	local nx, xmax, ymax = Nx, Nx * 4, Ny * 4

	-- Kick off the effect, starting at the centermost unit. If the cell list was empty, do
	-- nothing; the timer will cancel itself on the first go.
	local i1, nwork, nidle = grid.CellToIndex(MidCol * 4 - 2, MidRow * 4 - 2, xmax), 0, 0

	if #cells > 0 then
		work[1], nwork = i1, 1

		used("mark", i1)
	end

	-- Run a timer until all units are explored.
	local on_done = opts and opts.on_done

	return timers.RepeatEx(function(event)
		if nwork + nidle == 0 then
			-- Remove any display object references and recache the flood fill state.
			for i = #cells, 1, -1 do
				cells[i] = nil
			end

			Arrays[#Arrays + 1] = cells
			Arrays[#Arrays + 1] = work
			Arrays[#Arrays + 1] = idle
			Used[#Used + 1] = used

			-- Perform any on-done logic and kill the timer.
			if on_done then
				on_done(event.source)
			end

			return "cancel"
		end

		-- Run a few flood-fill iterations.
		for _ = 1, niters do
			-- Decide how many units to process on this iteration. If there are too few ready
			-- to go, try to grab some (randomly) to make up the balance 
			local to_process = random(nlow, nhigh)

			if nwork < to_process then
				for _ = nidle, max(1, nidle - to_process), -1 do
					local index = random(nidle)

					nwork, work[nwork + 1] = nwork + 1, idle[index]
					idle[index] = idle[nidle]
					nidle, idle[nidle] = nidle - 1
				end
			end

			-- Process a few units.
			for _ = nwork, max(1, nwork - to_process), -1 do
				-- Choose a random unit and mark the corresponding bit in its cell.
				local index = random(nwork)
				local x, y = grid.IndexToCell(work[index], xmax)
				local xb, yb = floor((x - 1) * .25), floor((y - 1) * .25)
				local xoff, yoff = x - xb * 4 - 1, y - yb * 4 - 1
				local ci = yb * nx + xb + 1
				local ceffect = cells[ci].fill.effect

				ceffect.bits = ceffect.bits + 2^(yoff * 4 + xoff)

				-- Update the cell with respect to each cardinal direction.
				for _, func in ipairs(Funcs) do
					local wi, delta, nbit_self, nbit_other = func(x, y, xoff, yoff, xmax, ymax)

					if wi then
						-- If the next unit over is inside a different cell, update the
						-- appropriate neighbor bits of both cells.
						local neighbor = delta and cells[ci + delta]

						if neighbor then
							local neffect = neighbor.fill.effect

							ceffect.neighbors = powers_of_2.Set(ceffect.neighbors, nbit_self)
							neffect.neighbors = powers_of_2.Set(neffect.neighbors, nbit_other)
						end

						-- If the non-boundary neighbor unit was unexplored and is not empty,
						-- add it to the to-be-processed list.
						if neighbor ~= false and used("mark", wi) then
							idle[nidle + 1], nidle = wi, nidle + 1
						end
					end
				end

				-- Backfill the completed unit.
				work[index] = work[nwork]
				nwork, work[nwork] = nwork - 1
			end
		end
	end, 100)
end

-- Export the module.
return M