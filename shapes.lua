--- Functionality related to dot shapes.

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
local abs = math.abs
local ipairs = ipairs
local pairs = pairs
local sort = table.sort

-- Modules --
local array_funcs = require("tektite_core.array.funcs")
local array_preds = require("tektite_core.array.predicates")
local fillers = require("s3_utils.object.fillers")
local movement = require("s3_utils.movement")
local tile_flags = require("s3_utils.tile_flags")
local tile_maps = require("s3_utils.tile_maps")

-- Corona globals --
local display = display
local Runtime = Runtime

-- Imports --
local IsFlagSet = tile_flags.IsFlagSet

-- Exports --
local M = {}

--
--
--

-- Lists of shapes to which given points belong --
local Shapes

--- DOCME
-- @uint index
function M.AddPoint (index)
	Shapes[index] = Shapes[index] or {}
end

-- Background layer --
local BG

-- Secondary background layer on which fill effects are put --
local FillLayer

-- Per-row lists of spans --
local Rows

-- Helper to fill a shape, processing its tile structure
local function FillShape (_, tiles)
	-- We'll process our tiles from top to bottom, starting from the left-hand side of each
	-- row, since this consists of just iterating the tiles in index order.
	local indices = array_funcs.GetKeys(tiles)

	sort(indices)

	-- Make a first pass over each row to accumulate its tile spans, i.e. each consecutive
	-- pair of tiles with a downward-exiting path and any tiles in between.
	local ncols, row, next, left, from = tile_maps.GetCounts(), 0, 0

	for _, cur in ipairs(indices) do
		while next < cur do
			next, row, from = next + ncols, row + 1
		end

		left = next - ncols

		if IsFlagSet(cur, "down") then
			-- Left side of span: If this is the first span in the row, do some bookkeeping.
			-- Remember the left column. 
			if not from then
				from = cur

			-- Right side: add the right column to the row's spans, indexed by left column.
			-- Go back to watching for a left side tile. If a row of tiles snuck between the
			-- columns, make the offset negative.
			else
				local offset = cur - left

				if IsFlagSet(from, "right") or IsFlagSet(cur, "left") then
					offset = -offset
				end

				Rows[row][from - left], from = offset
			end
		end
	end

	-- Start a new shape fill.
	fillers.Begin_Color(FillLayer, 1, 0, 0)

	-- Backtrack to the first occupied row, then iterate through each row and its spans.
	left = left - (row - 1) * ncols

	for i = 1, row do
		for from, to in pairs(Rows[i]) do
			to = abs(to)

			-- This span will be the top side of a box. We search each consecutive row until
			-- we find a row without a matching span, or full of tiles. The box's height is
			-- augmented by each match. The original span and all matches are removed.
			local bleft = left

			for j = i, row do
				local cur, up_to = Rows[j]

				up_to, cur[from] = cur[from]

				if abs(up_to or 0) == to and (j == i or up_to > 0) then
					bleft = bleft + ncols
				else
					break
				end
			end

			-- Add the rectangular component to the fill.
			fillers.AddRegion(left + from, bleft + to)
		end

		left = left + ncols
	end

	-- Commit the fill.
	fillers.End("flood_fill")
end

--- DOCME
-- @uint index
function M.RemoveAt (index)
	local shapes = Shapes[index]

	for i = #(shapes or ""), 1, -1 do
		shapes[i]:RemoveDot()

		shapes[i] = nil
	end
end

-- Helper to add intermediate fill layer
local function AddFillLayer ()
	FillLayer = display.newGroup()

	BG:insert(FillLayer)
end

-- Indicates whether the shape defined by a group of corners is listed yet
local function InShapesList (shapes, corners)
	-- Since the same loop may be found by exploring in different directions, we can end up
	-- with different orderings of the same set of corner tiles, i.e. an equivalence class
	-- for the shape. The sorted order is as good a canonical form as any, so we impose it
	-- on the corners, making them trivial to compare against the (also sorted) shape.
	sort(corners)

	-- Report if the loop is in the list anywhere.
	for _, shape in ipairs(shapes) do
		if array_preds.ShallowEqual(shape, corners) then
			return true
		end
	end

	-- Now it's in the list too.
	shapes[#shapes + 1] = corners
end

-- State for alternate attempts --
local Alts = {}

-- Detect if an alternate would have made a better loop
local function BetterAlt (attempted, n)
	local nrows, ncols = tile_maps.GetCounts()

	for i = 1, n, 3 do
		local dir, dt = Alts[i + 1], Alts[i + 2]
		local tile = Alts[i] + dt
		local col, row = tile_maps.GetCell(tile)

		if dir == "left" or dir == "right" then
			col = dir == "right" and ncols or 1
		else
			row = dir == "down" and nrows or 1
		end

		local endt = tile_maps.GetTileIndex(col, row)

		if dt < 0 then
			tile, endt = endt, tile
		end

		for j = tile, endt, dt do
			if attempted[j] then
				return true
			end
		end
	end
end

--
local function NewShape (dots, tiles)
	local Shape, count = {}, #dots

	--- @type shape

	--- Predicate.
	-- @uint index Tile index.
	-- @treturn boolean The tile at this index is part of the shape exterior?
	function Shape:HasTile (index)
		return tiles[index] ~= nil
	end

	--- Logically removes a dot from the shape.
	--
	-- If the dot count goes to 0, the shape is filled and the **filled_shape** event
	-- list is dispatched with the shape in key **shape**.
	function Shape:RemoveDot ()
		count = count - 1

		if count == 0 then
			FillShape(self, tiles)

			Runtime:dispatchEvent{ name = "filled_shape", shape = self }
		end
	end

	--- DOCME
	function Shape:Visit (func, context)
		for index in pairs(tiles) do
			func(index, context)
		end
	end

	Runtime:dispatchEvent{ name = "new_shape", shape = Shape }

	return Shape
end

-- Tries to form a closed loop containing a given tile
local function TryLoop (attempted, dots, corners, tile, facing, pref, alt)
	local start_tile, nalts = tile, 0

	repeat
		attempted[tile] = true

		-- If there is a dot here that may belong to shapes, track it.
		if Shapes[tile] then
			dots[#dots + 1] = tile
		end

		-- If there's a corner or junction on this tile, add its index to the list. Indices
		-- are easy to sort, and the actual corners aren't important, only that a unique
		-- sequence was recorded for later comparison.
		if not tile_flags.IsStraight(tile) then
			corners[#corners + 1] = tile
		end

		-- Try to advance. If we have to turn around, there's no loop.
		local going, dt = movement.WayToGo(tile, pref, "forward", alt, facing)

		if going == "backward" then
			return false

		-- We may overlook a better alternative by following our preference. In that case,
		-- our inferior shape would enclose the other path, so we can detect this case by
		-- heading straight out in the alternate direction until we hit an edge.
		elseif going ~= alt and tile ~= start_tile and movement.CanGo(tile, alt, facing) then
			Alts[nalts + 1] = tile
			Alts[nalts + 2], Alts[nalts + 3] = movement.NextDirection(facing, alt, "tile_delta")

			nalts = nalts + 3
		end

		-- Advance to the next tile. On the first tile, stay the course moving forward.
		facing, dt = movement.NextDirection(facing, tile ~= start_tile and going or "forward", "tile_delta")

		tile = tile + dt
	until attempted[tile]

	-- Completed a loop: was it back to where we started, and the best there was?
	return tile == start_tile and not BetterAlt(attempted, nalts)
end

-- Helper to discover new shapes by finding minimum loops
local function Explore (shapes, tile, dot_shapes, which, pref, alt)
	if not dot_shapes[which] then
		local attempt, dots, corners = {}, {}, {}

		if TryLoop(attempt, dots, corners, tile, which, pref, alt) and not InShapesList(shapes, corners) then
			local shape = NewShape(dots, attempt)

			-- Now that we have a new shape that knows about all of its dots, return the
			-- favor and tell the dots the shape holds them. Also, we may not have gone
			-- exploring from some of these dots yet, but we already know they will end
			-- up on this same loop / shape when heading in this direction, so we mark
			-- each dot to avoid wasted effort.
			for _, dot_index in ipairs(dots) do
				local shape_info = Shapes[dot_index]

				if shape_info then
					shape_info[which] = true

					shape_info[#shape_info + 1] = shape
				end
			end
		end
	end
end

-- Helper to bake dots into shapes
local function BakeShapes (event)
	local shapes = {}

	for i, dot_shapes in pairs(Shapes) do
		for dir in movement.Ways(i) do
			Explore(shapes, i, dot_shapes, dir, "to_left", "to_right")
			Explore(shapes, i, dot_shapes, dir, "to_right", "to_left")
		end
	end
end

for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		BG = level.bg_layer
		Rows = array_funcs.ArrayOfTables(level.nrows)
		Shapes = {}

		AddFillLayer()
	end,

	-- Leave Level --
	leave_level = function()
		BG, FillLayer, Rows, Shapes = nil
	end,

	-- Post-Reset --
	post_reset = BakeShapes,

	-- Reset Level --
	reset_level = function()
		for i in pairs(Shapes) do
			Shapes[i] = {}
		end

		FillLayer:removeSelf()

		AddFillLayer()
	end,

	-- Tiles Changed --
	tiles_changed = function(event)
		for i in pairs(Shapes) do
			Shapes[i] = {}
		end

		BakeShapes(event)
	end,

	-- Things Loaded --
	things_loaded = BakeShapes
} do
	Runtime:addEventListener(k, v)
end

return M