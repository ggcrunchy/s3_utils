--- This module deals with the grid of tiles (and their metadata) underlying the level.

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

-- Modules --
local enums = require("s3_utils.enums")
local tile_flags = require("s3_utils.tile_flags")
local tile_layout = require("s3_utils.tile_layout")

-- Solar2D globals --
local display = display

-- Module --
local M = {}

--
--
--

local Left, Right, Up, Down = enums.GetFlagByName("left"), enums.GetFlagByName("right"), enums.GetFlagByName("up"), enums.GetFlagByName("down")

local NameToFlags = {
	Horizontal = Left + Right, Vertical = Up + Down,

	UpperLeft = Right + Down, LowerLeft = Right + Up,
	UpperRight = Left + Down, LowerRight = Left + Up,

	LeftNub = Right, RightNub = Left,
	BottomNub = Up, TopNub = Down
}

NameToFlags.TopT = NameToFlags.Horizontal + Down
NameToFlags.LeftT = NameToFlags.Vertical + Right
NameToFlags.RightT = NameToFlags.Vertical + Left
NameToFlags.BottomT = NameToFlags.Horizontal + Up
NameToFlags.FourWays = NameToFlags.Horizontal + NameToFlags.Vertical
-- ^^ TODO: does this belong elsewhere?

local Tiles

--- Add a set of tiles to the level, adding and resolving the associated flags.
--
-- Currently, this is assumed to be a one-time operation on level load.
-- @pgroup group Group to which tiles are added.
-- @callable new_tile TODO
-- @array names Names of tiles, from upper-left to lower-right (left to right over each row).
--
-- Unrecognized names will be left blank (the editor names blank tiles **false**). The array
-- is padded with blanks to ensure its length is a multiple of the columns count.
-- @see s3_utils.tile_flags.Resolve
function M.AddTiles (group, new_tile, names)
	local ncols, w, h = tile_layout.GetCounts(), tile_layout.GetSizes()
	local index, y, n = 1, .5 * h, #names

	while index <= n do
		local x = .5 * w

		for _ = 1, ncols do
			local name = names[index]
			local flags = NameToFlags[name]

			-- TODO: We might eventually want animating tiles...
			if flags then
				Tiles[index] = new_tile(group, name, x, y, w, h)
			end

			tile_flags.SetFlags(index, flags)

			index, x = index + 1, x + w
		end

		y = y + h
	end

	tile_flags.Resolve()
end

--- Getter.
-- @int index Tile index.
-- @treturn DisplayObject Tile image, or **nil** if _index_ is invalid or the tile is blank.
function M.GetImage (index)
	return Tiles[index]
end

local FlagsToName = {}

for k, v in pairs(NameToFlags) do
	FlagsToName[v] = k
end

local function AuxSetTilesFromFlags (index, group, new_tile)
	local flags = tile_flags.GetFlags(index)

	display.remove(Tiles[index])

	if flags ~= 0 then
		local x, y = tile_layout.GetPosition(index)

		Tiles[index] = new_tile(group, --[[tile_flags.GetNameByFlags(flags)]]FlagsToName[flags], x, y, tile_layout.GetSizes())
	else
		Tiles[index] = nil
	end
end

--- Update the tiles in a rectangular region to reflect the current resolved flags, cf.
-- @{s3_utils.tile_flags.Resolve}.
-- @pgroup group Group to which tiles are added.
-- @callable new_tile TODO
-- @int col1 Column of one corner...
-- @int row1 ...row of one corner...
-- @int col2 ...column of another corner... (Columns will be sorted, and clamped.)
-- @int row2 ...and row of another corner. (Rows too.)
function M.SetTilesFromFlags (group, new_tile, col1, row1, col2, row2)
	tile_layout.VisitRegion(AuxSetTilesFromFlags, col1, row1, col2, row2, group, new_tile)
end

for k, v in pairs{
	enter_level = function()
		Tiles = {}
	end,

	leave_level = function()
		Tiles = nil
	end
} do
	Runtime:addEventListener(k, v)
end

return M