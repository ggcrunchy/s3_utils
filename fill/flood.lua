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
local timers = require("corona_utils.timers")

-- Plugins --
local memoryBitmap = require("plugin.memoryBitmap")

-- Corona globals --
local display = display
local graphics = graphics

-- Exports --
local M = {}

-- --
local CellW, CellH = 16, 16

-- --
local OffsetX, OffsetY = CellW - 1, CellH - 1

-- --
local HalfW, HalfH = CellW / 2, CellH / 2

-- --
local FracW, FracH = 1 / CellW, 1 / CellH

-- Helpers to look at next unit over --
local Funcs = {
	-- Left --
	function(x, y, xoff, _, xmax)
		local index = x > 1 and grid.CellToIndex(x - 1, y, xmax)

		if xoff > 0 then
			return index
		else
			return index, index and -1
		end
	end,

	-- Right --
	function(x, y, xoff, _, xmax)
		local index = x < xmax and grid.CellToIndex(x + 1, y, xmax)

		if xoff < OffsetX then
			return index
		else
			return index, index and 1
		end
	end,

	-- Up --
	function(x, y, _, yoff, xmax)
		local index = y > 1 and grid.CellToIndex(x, y - 1, xmax)

		if yoff > 0 then
			return index
		else
			return index, index and -FracW * xmax
		end
	end,

	-- Down --
	function(x, y, _, yoff, xmax, ymax)
		local index = y < ymax and grid.CellToIndex(x, y + 1, xmax)

		if yoff < OffsetY then
			return index
		else
			return index, index and FracW * xmax
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
-- @see Run
function M.Add (col, row)
	local dist_sq = (col - CX)^2 + (row - CY)^2

	if dist_sq < Closest then
		Closest, MidCol, MidRow = dist_sq, col, row
	end

	Cells[grid.CellToIndex(col, row, Nx)] = true
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
	Nx, Ny, Closest, CX, CY = nx, ny, 1 / 0, (nx + 1) / 2, (ny + 1) / 2
end

-- Cache of grid use wrappers --
local Used = {}

-- Adjust dimensions to mask-appropriate amounts
local function RoundUpMask (x)
	local xx = x + 13 -- 3 black pixels per side, for mask, plus 7 to round
					  -- all but multiples of 8 past the next such multiple
	local dim = xx - xx % 8 -- Remove the overshot to land on a multiple

	return dim, (dim - x) / 2
end

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
-- * **backdrop**: If present, backdrop to be exposed when updating cells.
-- @treturn TimerHandle Timer underlying the effect, which may be canceled.
-- @see Add, Prepare
function M.Run (backdrop, opts)
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
	local nx, xmax, ymax = Nx, Nx * CellW, Ny * CellH

	-- Kick off the effect, starting at the centermost unit. If the cell list was empty, do
	-- nothing; the timer will cancel itself on the first go.
	local midc, midr = MidCol * CellW - (Nx % 2) * HalfW, MidRow * CellH - (Ny % 2) * HalfH
	local i1, nwork, nidle = grid.CellToIndex(midc, midr, xmax), 0, 0

	if #cells > 0 then
		work[1], nwork = i1, 1

		used("mark", i1)
	end

	-- Add the backdrop.
	local w2, xx = RoundUpMask(xmax)
	local h2, yy = RoundUpMask(ymax)
	local mtex = memoryBitmap.newTexture{ width = w2, height = h2, format = "mask" }
	local mask = graphics.newMask(mtex.filename, mtex.baseDir)

	backdrop:addEventListener("finalize", function()
		mtex:releaseSelf()
	end)
	backdrop:setMask(mask)

	backdrop.maskScaleX, backdrop.maskScaleY = backdrop.width / xmax, backdrop.height / ymax

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
				-- Choose a random unit and expose it completely.
				local index = random(nwork)
				local x, y = grid.IndexToCell(work[index], xmax)
				local xb, yb = floor((x - 1) * FracW), floor((y - 1) * FracH)
				local xoff, yoff = x - xb * CellW - 1, y - yb * CellH - 1
				local ci = yb * nx + xb + 1

				mtex:setPixel(x + xx, y + yy, 1)

				-- Update the cell with respect to each cardinal direction.
				for _, func in ipairs(Funcs) do
					local wi, delta = func(x, y, xoff, yoff, xmax, ymax)

					-- If the non-boundary neighbor unit was unexplored and is not empty,
					-- add it to the to-be-processed list.
					if wi then
						local neighbor = delta and cells[ci + delta]

						if neighbor ~= false and used("mark", wi) then
							idle[nidle + 1], nidle = wi, nidle + 1

							local c, r = grid.IndexToCell(wi, xmax)

							mtex:setPixel(c + xx, r + yy, .5)
						end
					end
				end

				-- Backfill the completed unit.
				work[index] = work[nwork]
				nwork, work[nwork] = nwork - 1
			end
		end

		-- Update any underlying snapshot.
		if display.isValid(backdrop) then
			mtex:invalidate()
		end
	end, 15)
end

-- Export the module.
return M