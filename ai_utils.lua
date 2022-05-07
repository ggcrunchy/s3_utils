--- Various AI utilities.

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
local max = math.max
local min = math.min
local type = type

-- Modules --
local coro_flow = require("solar2d_utils.coro_flow")
local tile_layout = require("s3_utils.tile_layout")

-- Exports --
local M = {}

--
--
--

--- DOCME
-- @uint start
-- @uint halfx
-- @uint halfy
-- @callable gen
-- @treturn uint T
function M.GetTileNeighbor (start, halfx, halfy, gen)
	local col, row = tile_layout.GetCell(start)
	local ncols, nrows = tile_layout.GetCounts()
	local w, h, tile = 2 * halfx + 1, 2 * halfy + 1

	repeat
		col = min(ncols, max(col - halfx, 1) + gen() % w)
		row = min(nrows, max(row - halfy, 1) + gen() % h)
		tile = tile_layout.GetIndex(col, row)
	until tile ~= start

	return tile
end

--
--
--

local function BiasDim (n, bias)
  if n < 0 then
    return n - bias
  else
    return n + bias
  end
end

--- DOCME
-- @uint start
-- @uint halfx
-- @uint halfy
-- @callable gen
-- @int biasx
-- @int biasy
-- @treturn uint T
function M.GetTileNeighbor_Biased (start, halfx, halfy, gen, biasx, biasy)
	halfx, halfy = halfx - biasx, halfy - biasy

	local col, row = tile_layout.GetCell(start)
	local ncols, nrows = tile_layout.GetCounts()
	local w, h, tile = 2 * halfx + 1, 2 * halfy + 1, start

	repeat
		local gw = halfx - gen() % w + 1
		local gh = halfy - gen() % h + 1

		if gw ~= 0 and gh ~= 0 then
			col = max(1, min(col + BiasDim(gw, biasx), ncols))
			row = max(1, min(row + BiasDim(gh, biasy), nrows))
			tile = tile_layout.GetIndex(col, row)
		end
	until tile ~= start

	return tile
end

--
--
--

--- DOCME
-- @uint n
-- @number tolerx
-- @number tolery
-- @pobject target
-- @number dt
-- @callable update
-- @param arg
-- @treturn boolean B
-- @treturn number X
-- @treturn number Y
function M.SamplePositions (n, tolerx, tolery, target, dt, update, arg)
	local sumx, sumy, prevx, prevy = 0, 0
	local is_func = type(target) == "function"

	for i = 1, n do
		--
		if not coro_flow.Wait(dt, update, arg) then
			return false
		end

		--
		local x, y

		if is_func then
			x, y = target()
		else
			x, y = target.x, target.y
		end

		--
		if i > 1 and (abs(x - prevx) > tolerx or abs(y - prevy > tolery)) then
			return false
		end		

		prevx, sumx = x, sumx + x
		prevy, sumy = y, sumy + y
	end

	return true, sumx / n, sumy / n
end

--
--
--

return M