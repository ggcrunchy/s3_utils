--- Some utilities related to tile layouts.

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
local next = next

-- Modules --
local enums = require("s3_utils.enums")

-- Solar2D globals --
local display = display

-- Cached module references --
local _GetCell_
local _GetCell_XY_
local _GetFullHeight_
local _GetFullWidth_
local _GetIndex_
local _GetPosition_

-- Exports --
local M = {}

--
--
--

local Area

--- DOCME
function M.GetArea ()
	return Area
end

--
--
--

local ColumnCount, RowCount

---
-- @int index Tile index, assumed to be inside the level.
-- @treturn int Column corresponding to _index_...
-- @treturn int ...and row.
function M.GetCell (index)
	local col = (index - 1) % ColumnCount + 1
	local row = (index - col) / ColumnCount + 1

	return col, row
end

--
--
--

local Width, Height

---
-- @number x Position x-coordinate...
-- @number y ...and y-coordinate.
-- @treturn int Column of position's cell... (May be outside level.)
-- @treturn int ...and row. (Ditto.)
function M.GetCell_XY (x, y)
	return floor(x / Width) + 1, floor(y / Height) + 1
end

--
--
--

---
-- @treturn uint How many columns wide is each row...
-- @treturn uint ...and how many rows tall is each column?
function M.GetCounts ()
	return ColumnCount, RowCount
end

--
--
--

local Directions = { left = true, right = true, up = true, down = true }

local function AuxDirectionsFromFlags (flags, dir)
	for k in next, Directions, dir do
		if enums.IsFlagSet(flags, k) then
			return k
		end
	end
end

--- Iterate over the directions described by a combination of flags.
-- @uint flags
-- @treturn iterator Supplies direction.
function M.GetDirectionsFromFlags (flags)
	return AuxDirectionsFromFlags, flags or 0
end

--
--
--

--- DOCME
function M.GetFullHeight (how)
  local height = RowCount * Height
  local ch = how == "match_content" and display.contentHeight

  if ch and ch > height then
    return ch
  else
    return height
  end
end

--
--
--

--- DOCME
function M.GetFullSizes (how)
	return _GetFullWidth_(how), _GetFullHeight_(how)
end

--
--
--

--- DOCME
function M.GetFullWidth (how)
  local width = ColumnCount * Width
  local cw = how == "match_content" and display.contentWidth

  if cw and cw > width then
    return cw
  else
    return width
  end
end

--
--
--

---
-- @int col Tile column...
-- @int row ...and row.
-- @treturn int Tile index, or -1 if outside the level.
function M.GetIndex (col, row)
	if col >= 1 and col <= ColumnCount and row >= 1 and row <= RowCount then
		return (row - 1) * ColumnCount + col
	else
		return -1
	end
end

--
--
--

---
-- @number x Position x-coordinate...
-- @number y ...and y-coordinate.
-- @treturn int Tile index, or -1 if outside the level.
function M.GetIndex_XY (x, y)
	return _GetIndex_(_GetCell_XY_(x, y))
end

--
--
--

---
-- @uint index
--
-- If the index is invalid or outside the level, falls back to the upper-left tile.
-- @treturn number Tile center x-coordinate...
-- @treturn number ...and y-coordinate.
function M.GetPosition (index)
	if index >= 1 and index <= Area then
		local col, row = _GetCell_(index)

		return (col - .5) * Width, (row - .5) * Height
	else
		return 0, 0
	end
end

--
--
--

-- DOCME
function M.GetSizes ()
	return Width, Height
end

--
--
--

--- DOCME
function M.IsJunction (flags)
	local n = 0

	if flags >= 0x8 then
		n, flags = 1, flags - 0x8
	end

	if flags >= 0x4 then
		n, flags = n + 1, flags - 0x4
	end

	if flags >= 0x2 then
		n, flags = n + 1, flags - 0x2
	end

	return n + flags > 2 -- flags now 0 or 1
end

--
--
--

local Horizontal = enums.GetFlagByName("left") + enums.GetFlagByName("right")
local Vertical = enums.GetFlagByName("up") + enums.GetFlagByName("down")

--- DOCME
function M.IsStraight (flags)
	return flags == Horizontal or flags == Vertical
end

--
--
--

---
-- @uint index Tile index (see the caveat for @{GetTilePos}).
-- @param object The tile center is assigned to this object's **x** and **y** fields.
function M.PutObjectAt (index, object)
	object.x, object.y = _GetPosition_(index)
end

--
--
--

--- DOCME
function M.SetCounts (column_count, row_count)
	Area, ColumnCount, RowCount = column_count * row_count, column_count, row_count
end

--
--
--

--- DOCME
function M.SetSizes (width, height)
	Width, Height = width, height
end

--
--
--

local function MinMaxN (a, b, n)
	if b < a then
		a, b = b, a
	end

	if b < 1 or a > n then
		return 1, 0 -- empty range
	else
		return a >= 1 and a or 1, b <= n and b or n
	end
end

--- BLARGH
-- @callable func
-- @int col1 Column of one corner...
-- @int row1 ...row of one corner...
-- @int col2 ...column of another corner... (Columns will be sorted, and clamped.)
-- @int row2 ...and row of another corner. (Rows too.)
-- @param arg1
-- @param arg2
function M.VisitRegion (func, col1, row1, col2, row2, arg1, arg2)
	col1, col2 = MinMaxN(col1, col2, ColumnCount)
	row1, row2 = MinMaxN(row1, row2, RowCount)

	local index = (row1 - 1) * ColumnCount + col1

	for _ = row1, row2 do
		for i = 0, col2 - col1 do
			func(index + i, arg1, arg2)
		end

		index = index + ColumnCount
	end
end

--
--
--

_GetCell_ = M.GetCell
_GetCell_XY_ = M.GetCell_XY
_GetFullHeight_ = M.GetFullHeight
_GetFullWidth_ = M.GetFullWidth
_GetIndex_ = M.GetIndex
_GetPosition_ = M.GetPosition

return M